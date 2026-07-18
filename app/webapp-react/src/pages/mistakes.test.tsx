import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { MistakesPage } from './MistakesPage';

// All network I/O mocked; the destructive endpoints (PATCH/POST/DELETE)
// only ever see fixture ids.

function fixtureData(overrides: Partial<Record<string, unknown>> = {}) {
    return {
        counts: { total: 2, correctionDone: 1, resolved: 1, pendingRetests: 1 },
        retestQueue: [
            { scheduledFor: '2020-01-01', summary: 'Old NetworkPolicy drill' },
            { scheduledFor: '2999-01-01', summary: 'Future RBAC drill' }
        ],
        categories: ['CKA', 'CKS'],
        mistakes: [
            {
                mistakeId: 'm-1',
                category: 'CKA',
                summary: 'Wrong selector in NetworkPolicy',
                createdAt: '2026-07-01T10:00:00.000Z',
                resolved: false,
                rootCauseNote: 'Forgot podSelector matches pods, not namespaces',
                correction: { status: 'planned', note: 'Redo killercoda drill' },
                retests: [
                    { retestId: 'r-1', scheduledFor: '2026-07-20', result: 'pending' },
                    { retestId: 'r-2', scheduledFor: '2026-06-20', result: 'passed' }
                ],
                source: {
                    labId: 'cka-001',
                    labName: 'CKA Mock 1',
                    questionId: 4,
                    certificationCode: 'CKA',
                    attemptId: 'a-77'
                }
            },
            {
                mistakeId: 'm-2',
                category: 'CKS',
                summary: 'Falco rule syntax',
                createdAt: '2026-07-02T10:00:00.000Z',
                resolved: true,
                correction: { status: 'done' },
                retests: [],
                source: { labId: 'cks-002', questionId: 9, attemptId: 'a-78' }
            }
        ],
        ...overrides
    };
}

function jsonResponse(body: unknown, ok = true, status = ok ? 200 : 500) {
    return { ok, status, json: () => Promise.resolve(body) } as Response;
}

function renderPage() {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    return render(
        <QueryClientProvider client={client}>
            <ThemeProvider>
                <ToastProvider>
                    <MistakesPage />
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

function listUrl(url: string) {
    return url.startsWith('/facilitator/api/v1/mistakes?');
}

describe('MistakesPage', () => {
    it('renders counters, retest queue with DUE/SCHEDULED, and mistake cards', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await waitFor(() => expect(screen.getByText('Captured mistakes')).toBeInTheDocument());
        expect(screen.getByText('Retests pending')).toBeInTheDocument();
        expect(screen.getByText('DUE')).toBeInTheDocument();
        expect(screen.getByText('SCHEDULED')).toBeInTheDocument();
        expect(screen.getByText('Wrong selector in NetworkPolicy')).toBeInTheDocument();
        expect(screen.getByText('OPEN')).toBeInTheDocument();
        expect(screen.getByText('RESOLVED')).toBeInTheDocument();
        expect(screen.getByText('CORRECTION: PLANNED')).toBeInTheDocument();
        expect(screen.getByText('CORRECTION: DONE')).toBeInTheDocument();
        expect(screen.getByText('PASSED')).toBeInTheDocument();
        expect(screen.getByText('PENDING')).toBeInTheDocument();
        // First load fetches with empty filter params
        expect(fetchMock.mock.calls[0]![0]).toBe('/facilitator/api/v1/mistakes?');
    });

    it('applies category and resolved filters as query params', async () => {
        const seen: string[] = [];
        fetchMock.mockImplementation((url: string) => {
            if (listUrl(url)) {
                seen.push(url);
                return Promise.resolve(jsonResponse({ data: fixtureData() }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('CKA Mock 1', { exact: false })).toBeInTheDocument());
        await user.selectOptions(document.getElementById('categoryFilter') as HTMLSelectElement, 'CKS');
        await waitFor(() =>
            expect(seen).toContain('/facilitator/api/v1/mistakes?category=CKS')
        );
        await user.selectOptions(document.getElementById('resolvedFilter') as HTMLSelectElement, 'false');
        await waitFor(() =>
            expect(seen).toContain('/facilitator/api/v1/mistakes?category=CKS&resolved=false')
        );
        // Category options survive filtering (populated once)
        const options = Array.from(
            (document.getElementById('categoryFilter') as HTMLSelectElement).options
        ).map((option) => option.value);
        expect(options).toEqual(['', 'CKA', 'CKS']);
    });

    it('shows the empty state when no mistakes exist', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (listUrl(url)) {
                return Promise.resolve(
                    jsonResponse({
                        data: fixtureData({
                            mistakes: [],
                            retestQueue: [],
                            counts: { total: 0, correctionDone: 0, resolved: 0, pendingRetests: 0 }
                        })
                    })
                );
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await waitFor(() =>
            expect(screen.getByText(/No mistakes captured yet\./)).toBeInTheDocument()
        );
        expect(
            screen.getByText('No retests scheduled. Schedule one from a mistake below.')
        ).toBeInTheDocument();
    });

    it('shows the legacy failure message when the list cannot load', async () => {
        fetchMock.mockImplementation(() => Promise.reject(new Error('down')));
        renderPage();
        await waitFor(() =>
            expect(document.getElementById('mistakesStatus')).toHaveTextContent(
                'Failed to load mistakes.'
            )
        );
    });

    it('records a correction via PATCH with the typed note and refreshes', async () => {
        let patchBody: unknown = null;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            if (url === '/facilitator/api/v1/mistakes/m-1/correction') {
                expect(options?.method).toBe('PATCH');
                patchBody = JSON.parse(String(options?.body));
                return Promise.resolve(jsonResponse({ data: {} }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Wrong selector in NetworkPolicy')).toBeInTheDocument());
        const noteInput = document.querySelector('[data-note-input="m-1"]') as HTMLInputElement;
        await user.type(noteInput, 'Practice label selectors');
        await user.click(screen.getAllByRole('button', { name: 'Mark correction done' })[0]!);

        await waitFor(() => expect(patchBody).toEqual({ status: 'done', note: 'Practice label selectors' }));
    });

    it('omits the note field when the note input is empty (legacy body shape)', async () => {
        let patchBody: unknown = null;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            if (url === '/facilitator/api/v1/mistakes/m-1/correction') {
                patchBody = JSON.parse(String(options?.body));
                return Promise.resolve(jsonResponse({ data: {} }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Wrong selector in NetworkPolicy')).toBeInTheDocument());
        await user.click(screen.getAllByRole('button', { name: 'Plan correction' })[0]!);
        await waitFor(() => expect(patchBody).toEqual({ status: 'planned' }));
    });

    it('schedules a retest via POST with the picked date', async () => {
        let postBody: unknown = null;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            if (url === '/facilitator/api/v1/mistakes/m-1/retests') {
                expect(options?.method).toBe('POST');
                postBody = JSON.parse(String(options?.body));
                return Promise.resolve(jsonResponse({ data: {} }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Wrong selector in NetworkPolicy')).toBeInTheDocument());
        const dateInput = document.getElementById('retest-date-m-1') as HTMLInputElement;
        await user.type(dateInput, '2026-08-01');
        await user.click(screen.getAllByRole('button', { name: 'Schedule retest' })[0]!);

        await waitFor(() => expect(postBody).toEqual({ scheduledFor: '2026-08-01' }));
    });

    it('records a retest result via PATCH on the retest resource', async () => {
        let patched: { url: string; body: unknown } | null = null;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            if (url === '/facilitator/api/v1/mistakes/m-1/retests/r-1') {
                expect(options?.method).toBe('PATCH');
                patched = { url, body: JSON.parse(String(options?.body)) };
                return Promise.resolve(jsonResponse({ data: {} }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Record pass')).toBeInTheDocument());
        await user.click(screen.getByRole('button', { name: 'Record pass' }));

        await waitFor(() => expect(patched).toEqual({
            url: '/facilitator/api/v1/mistakes/m-1/retests/r-1',
            body: { result: 'passed' }
        }));
    });

    it('delete requires confirmation and issues DELETE', async () => {
        let deleted = false;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            if (url === '/facilitator/api/v1/mistakes/m-2' && options?.method === 'DELETE') {
                deleted = true;
                return Promise.resolve(jsonResponse({ data: {} }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Falco rule syntax')).toBeInTheDocument());
        await user.click(screen.getAllByRole('button', { name: 'Delete' })[1]!);

        expect(window.confirm).toHaveBeenCalledWith(
            'Delete this mistake record? This cannot be undone from the UI.'
        );
        await waitFor(() => expect(deleted).toBe(true));
    });

    it('declined delete confirmation issues no request', async () => {
        (window.confirm as ReturnType<typeof vi.fn>).mockReturnValue(false);
        fetchMock.mockImplementation((url: string) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Falco rule syntax')).toBeInTheDocument());
        await user.click(screen.getAllByRole('button', { name: 'Delete' })[0]!);
        expect(
            fetchMock.mock.calls.some(([, options]) => (options as RequestInit)?.method === 'DELETE')
        ).toBe(false);
    });

    it('a failed action alerts with the server message and keeps the page usable', async () => {
        vi.spyOn(window, 'alert').mockImplementation(() => {});
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            if (url === '/facilitator/api/v1/mistakes/m-1/correction') {
                expect(options?.method).toBe('PATCH');
                return Promise.resolve(jsonResponse({ message: 'Mistake not found' }, false, 404));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Wrong selector in NetworkPolicy')).toBeInTheDocument());
        await user.click(screen.getAllByRole('button', { name: 'Plan correction' })[0]!);

        await waitFor(() =>
            expect(window.alert).toHaveBeenCalledWith('Action failed: Mistake not found')
        );
        expect(screen.getAllByRole('button', { name: 'Plan correction' })[0]!).toBeEnabled();
    });

    it('sets the legacy document title', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();
        await waitFor(() => expect(document.title).toBe('Mistakes & Retests | CK-X'));
    });

    it('keeps a pending action disabled while a second action starts (legacy per-button busy)', async () => {
        // Both mutation requests stay pending forever; each button must stay
        // disabled independently, matching legacy per-button disabling.
        fetchMock.mockImplementation((url: string) => {
            if (listUrl(url)) return Promise.resolve(jsonResponse({ data: fixtureData() }));
            if (
                url === '/facilitator/api/v1/mistakes/m-1/correction' ||
                url === '/facilitator/api/v1/mistakes/m-1/retests'
            ) {
                return new Promise(() => {});
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Wrong selector in NetworkPolicy')).toBeInTheDocument());
        const planBtn = screen.getAllByRole('button', { name: 'Plan correction' })[0]!;
        const scheduleBtn = screen.getAllByRole('button', { name: 'Schedule retest' })[0]!;

        await user.click(planBtn);
        await waitFor(() => expect(planBtn).toBeDisabled());

        await user.click(scheduleBtn);
        await waitFor(() => expect(scheduleBtn).toBeDisabled());
        // Starting the second action must not re-enable the first
        expect(planBtn).toBeDisabled();
    });
});
