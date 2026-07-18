import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { PacksPage } from './PacksPage';

// Fixtures only — pack deletion/import never touch a live facilitator.

const PACKS_URL = '/facilitator/api/v1/packs';

const FIXTURE_PACKS = [
    {
        id: 'cka-001',
        name: 'CKA Mock 1',
        category: 'CKA',
        examType: 'performance',
        questionCount: 17,
        imported: false
    },
    {
        id: 'kcna-community',
        name: 'Community KCNA',
        category: 'KCNA',
        examType: 'mcq',
        questionCount: 20,
        imported: true
    }
];

function jsonResponse(body: unknown, ok = true, status = ok ? 200 : 500) {
    return { ok, status, json: () => Promise.resolve(body) } as Response;
}

function renderPage() {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    return render(
        <QueryClientProvider client={client}>
            <ThemeProvider>
                <ToastProvider>
                    <PacksPage />
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}

const fetchMock = vi.fn();

beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
    fetchMock.mockReset();
    vi.spyOn(window, 'confirm').mockReturnValue(true);
});

afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
});

function mockPacksList(packs = FIXTURE_PACKS) {
    fetchMock.mockImplementation((url: string) => {
        if (url === PACKS_URL) {
            return Promise.resolve(jsonResponse({ data: { packs } }));
        }
        return Promise.reject(new Error(`Unexpected fetch: ${url}`));
    });
}

describe('PacksPage list', () => {
    it('renders installed packs with export links and delete only for imported', async () => {
        mockPacksList();
        renderPage();

        await waitFor(() => expect(screen.getByText('CKA Mock 1')).toBeInTheDocument());
        expect(screen.getByText('Performance (lab)')).toBeInTheDocument();
        expect(screen.getByText('Multiple choice')).toBeInTheDocument();
        expect(screen.getByText('imported')).toBeInTheDocument();
        expect(screen.getByText('built-in')).toBeInTheDocument();

        const exportLinks = screen.getAllByRole('link', { name: 'Export' });
        expect(exportLinks.map((a) => a.getAttribute('href'))).toEqual([
            '/facilitator/api/v1/packs/cka-001/export',
            '/facilitator/api/v1/packs/kcna-community/export'
        ]);
        exportLinks.forEach((a) => expect(a).toHaveAttribute('download'));

        // Only the imported pack row has a Delete button
        expect(screen.getAllByRole('button', { name: 'Delete' })).toHaveLength(1);
    });

    it('shows the legacy failure message when the pack list cannot load', async () => {
        fetchMock.mockImplementation(() => Promise.reject(new Error('down')));
        renderPage();
        await waitFor(() =>
            expect(document.getElementById('packsStatus')).toHaveTextContent('Failed to load packs.')
        );
    });

    it('delete asks for confirmation and calls DELETE, refreshing the list', async () => {
        const user = userEvent.setup();
        let deleted = false;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === PACKS_URL) {
                return Promise.resolve(
                    jsonResponse({ data: { packs: deleted ? [FIXTURE_PACKS[0]] : FIXTURE_PACKS } })
                );
            }
            if (url === '/facilitator/api/v1/packs/kcna-community' && options?.method === 'DELETE') {
                deleted = true;
                return Promise.resolve(jsonResponse({ data: {} }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await waitFor(() => expect(screen.getByText('Community KCNA')).toBeInTheDocument());
        await user.click(screen.getByRole('button', { name: 'Delete' }));

        expect(window.confirm).toHaveBeenCalledWith(
            'Delete imported pack "kcna-community" and its files? This cannot be undone from the UI.'
        );
        await waitFor(() => expect(screen.queryByText('Community KCNA')).not.toBeInTheDocument());
    });

    it('a declined confirmation issues no DELETE request', async () => {
        const user = userEvent.setup();
        (window.confirm as ReturnType<typeof vi.fn>).mockReturnValue(false);
        mockPacksList();
        renderPage();

        await waitFor(() => expect(screen.getByText('Community KCNA')).toBeInTheDocument());
        await user.click(screen.getByRole('button', { name: 'Delete' }));

        expect(
            fetchMock.mock.calls.some(([, options]) => (options as RequestInit)?.method === 'DELETE')
        ).toBe(false);
        expect(screen.getByText('Community KCNA')).toBeInTheDocument();
    });
});

describe('PacksPage import', () => {
    it('imports an MCQ bundle without the performance warning', async () => {
        const user = userEvent.setup();
        const bundle = { config: { examType: 'mcq' }, lab: { id: 'fixture' } };
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === PACKS_URL) {
                return Promise.resolve(jsonResponse({ data: { packs: [] } }));
            }
            if (url === '/facilitator/api/v1/packs/import' && options?.method === 'POST') {
                expect(JSON.parse(String(options.body))).toEqual(bundle);
                return Promise.resolve(jsonResponse({ data: { packId: 'fixture' } }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        const importButton = screen.getByRole('button', { name: 'Validate & import' });
        expect(importButton).toBeDisabled();

        const input = document.getElementById('importFileInput') as HTMLInputElement;
        await user.upload(
            input,
            new File([JSON.stringify(bundle)], 'ckx-pack-fixture.json', { type: 'application/json' })
        );
        expect(importButton).toBeEnabled();
        await user.click(importButton);

        await waitFor(() =>
            expect(document.getElementById('importStatus')).toHaveTextContent(
                'Imported "fixture". It now appears in the lab list on the home page.'
            )
        );
        expect(window.confirm).not.toHaveBeenCalled();
    });

    it('warns before importing a performance pack and cancels cleanly', async () => {
        const user = userEvent.setup();
        (window.confirm as ReturnType<typeof vi.fn>).mockReturnValue(false);
        mockPacksList([]);
        renderPage();

        const input = document.getElementById('importFileInput') as HTMLInputElement;
        await user.upload(
            input,
            new File([JSON.stringify({ lab: { id: 'perf' } })], 'ckx-pack-perf.json', {
                type: 'application/json'
            })
        );
        await user.click(screen.getByRole('button', { name: 'Validate & import' }));

        await waitFor(() =>
            expect(document.getElementById('importStatus')).toHaveTextContent('Import cancelled')
        );
        expect(String((window.confirm as ReturnType<typeof vi.fn>).mock.calls[0]![0])).toContain(
            'PERFORMANCE pack'
        );
        expect(
            fetchMock.mock.calls.some(([url]) => String(url).includes('/packs/import'))
        ).toBe(false);
    });

    it('lists server validation errors when an import is rejected', async () => {
        const user = userEvent.setup();
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === PACKS_URL) {
                return Promise.resolve(jsonResponse({ data: { packs: [] } }));
            }
            if (url === '/facilitator/api/v1/packs/import' && options?.method === 'POST') {
                return Promise.resolve(
                    jsonResponse(
                        { error: 'Import rejected', errors: ['marks must sum to 100', 'duplicate id q1'] },
                        false,
                        400
                    )
                );
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        const input = document.getElementById('importFileInput') as HTMLInputElement;
        await user.upload(
            input,
            new File([JSON.stringify({ config: { examType: 'mcq' } })], 'bad.json', {
                type: 'application/json'
            })
        );
        await user.click(screen.getByRole('button', { name: 'Validate & import' }));

        await waitFor(() =>
            expect(document.getElementById('importStatus')).toHaveTextContent('Import rejected')
        );
        const errors = document.getElementById('importErrors')!;
        expect(within(errors as HTMLElement).getByText('marks must sum to 100')).toBeInTheDocument();
        expect(within(errors as HTMLElement).getByText('duplicate id q1')).toBeInTheDocument();
    });

    it('rejects a non-JSON import file without any network call', async () => {
        const user = userEvent.setup();
        mockPacksList([]);
        renderPage();

        const input = document.getElementById('importFileInput') as HTMLInputElement;
        await user.upload(input, new File(['{broken'], 'bad.json', { type: 'application/json' }));
        await user.click(screen.getByRole('button', { name: 'Validate & import' }));

        await waitFor(() =>
            expect(document.getElementById('importStatus')).toHaveTextContent(
                'The selected file is not valid JSON'
            )
        );
        expect(
            fetchMock.mock.calls.some(([url]) => String(url).includes('/packs/import'))
        ).toBe(false);
    });
});

describe('PacksPage builder', () => {
    it('starts with two question rows, tracks weight total, and flags non-100 totals', async () => {
        const user = userEvent.setup();
        mockPacksList([]);
        renderPage();

        expect(screen.getAllByLabelText('Question text')).toHaveLength(2);
        const note = document.getElementById('builderWeightNote')!;
        expect(note).toHaveTextContent('Total weight: 0 / 100');

        const weights = screen.getAllByLabelText('Question weight');
        await user.type(weights[0]!, '60');
        expect(note).toHaveTextContent('Total weight: 60 / 100');
        expect(note.className).toContain('text-bad');
        await user.type(weights[1]!, '40');
        expect(note).toHaveTextContent('Total weight: 100 / 100');
        expect(note.className).not.toContain('text-bad');

        await user.click(screen.getByRole('button', { name: 'Add question' }));
        expect(screen.getAllByLabelText('Question text')).toHaveLength(3);
        await user.click(screen.getAllByRole('button', { name: 'Remove' })[2]!);
        expect(screen.getAllByLabelText('Question text')).toHaveLength(2);
    });

    it('validate posts to import?validateOnly=true and reports a valid bundle', async () => {
        const user = userEvent.setup();
        interface CapturedBundle {
            packFormatVersion: number;
            lab: { id: string };
            config: { examType: string };
            assessment: { questions: Record<string, unknown>[] };
        }
        let capturedBody: CapturedBundle | null = null;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === PACKS_URL) {
                return Promise.resolve(jsonResponse({ data: { packs: [] } }));
            }
            if (url === '/facilitator/api/v1/packs/import?validateOnly=true') {
                capturedBody = JSON.parse(String(options?.body));
                return Promise.resolve(jsonResponse({ data: { valid: true } }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await user.type(screen.getByLabelText('Pack id'), 'kcna-fixture');
        await user.type(screen.getByLabelText('Name'), 'Fixture Pack');
        const questionTexts = screen.getAllByLabelText('Question text');
        await user.type(questionTexts[0]!, 'What is a Pod?');
        const weights = screen.getAllByLabelText('Question weight');
        await user.type(weights[0]!, '100');
        const optionTexts = screen.getAllByLabelText('Option 1 text');
        await user.type(optionTexts[0]!, 'Smallest deployable unit');
        await user.click(screen.getAllByLabelText('Option 1 is correct')[0]!);

        await user.click(screen.getByRole('button', { name: 'Validate' }));

        await waitFor(() =>
            expect(document.getElementById('builderStatus')).toHaveTextContent('Bundle is valid.')
        );
        expect(capturedBody!.packFormatVersion).toBe(1);
        expect(capturedBody!.lab.id).toBe('kcna-fixture');
        expect(capturedBody!.config.examType).toBe('mcq');
        expect(capturedBody!.assessment.questions[0]).toMatchObject({
            id: '1',
            type: 'multiple-choice',
            question: 'What is a Pod?',
            options: ['Smallest deployable unit'],
            correctOptionIndexes: [0],
            weightage: 100
        });
    });

    it('validate failure lists builder errors', async () => {
        const user = userEvent.setup();
        fetchMock.mockImplementation((url: string) => {
            if (url === PACKS_URL) {
                return Promise.resolve(jsonResponse({ data: { packs: [] } }));
            }
            if (url === '/facilitator/api/v1/packs/import?validateOnly=true') {
                return Promise.resolve(
                    jsonResponse({ data: { valid: false, errors: ['weights must sum to 100'] } })
                );
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await user.click(screen.getByRole('button', { name: 'Validate' }));
        await waitFor(() =>
            expect(document.getElementById('builderStatus')).toHaveTextContent('Validation failed.')
        );
        expect(screen.getByText('weights must sum to 100')).toBeInTheDocument();
    });

    it('save posts to import?validateOnly=false and reports the saved pack', async () => {
        const user = userEvent.setup();
        fetchMock.mockImplementation((url: string) => {
            if (url === PACKS_URL) {
                return Promise.resolve(jsonResponse({ data: { packs: [] } }));
            }
            if (url === '/facilitator/api/v1/packs/import?validateOnly=false') {
                return Promise.resolve(jsonResponse({ data: { packId: 'kcna-saved' } }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await user.click(screen.getByRole('button', { name: 'Save as pack' }));
        await waitFor(() =>
            expect(document.getElementById('builderStatus')).toHaveTextContent(
                'Pack "kcna-saved" saved. It now appears in the lab list.'
            )
        );
    });

    it('save rejection surfaces the error and error list', async () => {
        const user = userEvent.setup();
        fetchMock.mockImplementation((url: string) => {
            if (url === PACKS_URL) {
                return Promise.resolve(jsonResponse({ data: { packs: [] } }));
            }
            if (url === '/facilitator/api/v1/packs/import?validateOnly=false') {
                return Promise.resolve(
                    jsonResponse({ error: 'Save rejected', errors: ['pack id already exists'] }, false, 409)
                );
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await user.click(screen.getByRole('button', { name: 'Save as pack' }));
        await waitFor(() =>
            expect(document.getElementById('builderStatus')).toHaveTextContent('Save rejected')
        );
        expect(screen.getByText('pack id already exists')).toBeInTheDocument();
    });
});

describe('PacksPage title', () => {
    it('sets the legacy document title', async () => {
        fetchMock.mockImplementation(() => Promise.reject(new Error('down')));
        renderPage();
        await waitFor(() => expect(document.title).toBe('Question Packs | CK-X'));
    });
});
