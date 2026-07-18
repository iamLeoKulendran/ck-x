import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { SettingsPage } from './SettingsPage';

// All fetches are mocked — no live facilitator data is ever touched, and
// the destructive endpoints (restore/reset) only ever see fixture payloads.

const INFO_URL = '/facilitator/api/v1/data/info';

function jsonResponse(body: unknown, ok = true, status = ok ? 200 : 500) {
    return {
        ok,
        status,
        json: () => Promise.resolve(body)
    } as Response;
}

function renderPage() {
    const client = new QueryClient({
        defaultOptions: { queries: { retry: false } }
    });
    return render(
        <QueryClientProvider client={client}>
            <ThemeProvider>
                <ToastProvider>
                    <SettingsPage />
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}

const fetchMock = vi.fn();

beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
    fetchMock.mockReset();
});

afterEach(() => {
    vi.unstubAllGlobals();
});

function mockInfoOnly(info: Record<string, unknown>) {
    fetchMock.mockImplementation((url: string) => {
        if (url === INFO_URL) {
            return Promise.resolve(jsonResponse({ data: info }));
        }
        return Promise.reject(new Error(`Unexpected fetch: ${url}`));
    });
}

describe('SettingsPage', () => {
    it('renders local data info from /data/info', async () => {
        mockInfoOnly({
            historyFile: '/data/history.json',
            historyVersion: 3,
            attemptCount: 12,
            telemetryEnabled: false
        });
        renderPage();

        await waitFor(() =>
            expect(screen.getByText('/data/history.json')).toBeInTheDocument()
        );
        expect(document.getElementById('infoHistoryVersion')).toHaveTextContent('v3');
        expect(document.getElementById('infoAttemptCount')).toHaveTextContent('12');
        expect(document.getElementById('infoTelemetry')).toHaveTextContent(
            'Disabled (local-only, default)'
        );
    });

    it('shows Unavailable in every info field when /data/info fails', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(jsonResponse({}, false, 500)));
        renderPage();

        await waitFor(() =>
            expect(document.getElementById('infoHistoryFile')).toHaveTextContent('Unavailable')
        );
        expect(document.getElementById('infoHistoryVersion')).toHaveTextContent('Unavailable');
        expect(document.getElementById('infoAttemptCount')).toHaveTextContent('Unavailable');
        expect(document.getElementById('infoTelemetry')).toHaveTextContent('Unavailable');
    });

    it('exposes the backup download as a plain anchor to /data/export', async () => {
        mockInfoOnly({ attemptCount: 0 });
        renderPage();
        const anchor = screen.getByRole('link', { name: 'Download backup' });
        expect(anchor).toHaveAttribute('href', '/facilitator/api/v1/data/export');
        expect(anchor).toHaveAttribute('download');
        // No fetch is issued for the export — the browser downloads it.
        await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(INFO_URL));
        expect(fetchMock.mock.calls.every(([url]) => url === INFO_URL)).toBe(true);
    });

    it('keeps restore disabled without a file and posts the parsed bundle when run', async () => {
        const user = userEvent.setup();
        const bundle = { historyVersion: 3, attempts: [{ id: 'fixture-a1' }] };
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === INFO_URL) {
                return Promise.resolve(jsonResponse({ data: { attemptCount: 1 } }));
            }
            if (url === '/facilitator/api/v1/data/restore') {
                expect(options?.method).toBe('POST');
                expect(options?.headers).toEqual({ 'Content-Type': 'application/json' });
                expect(JSON.parse(String(options?.body))).toEqual(bundle);
                return Promise.resolve(jsonResponse({ data: { attemptCount: 1 } }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        const restoreButton = screen.getByRole('button', { name: 'Restore from file' });
        expect(restoreButton).toBeDisabled();

        const input = document.getElementById('restoreFileInput') as HTMLInputElement;
        const file = new File([JSON.stringify(bundle)], 'backup.json', {
            type: 'application/json'
        });
        await user.upload(input, file);
        expect(restoreButton).toBeEnabled();

        await user.click(restoreButton);
        await waitFor(() =>
            expect(document.getElementById('restoreStatus')).toHaveTextContent(
                'Restored 1 attempts. Previous file was backed up.'
            )
        );
    });

    it('rejects a non-JSON restore file without calling the API', async () => {
        const user = userEvent.setup();
        mockInfoOnly({ attemptCount: 2 });
        renderPage();

        const input = document.getElementById('restoreFileInput') as HTMLInputElement;
        await user.upload(input, new File(['not json'], 'broken.json', { type: 'application/json' }));
        await user.click(screen.getByRole('button', { name: 'Restore from file' }));

        await waitFor(() =>
            expect(document.getElementById('restoreStatus')).toHaveTextContent(
                'Restore failed: The selected file is not valid JSON'
            )
        );
        expect(
            fetchMock.mock.calls.some(([url]) => String(url).includes('/data/restore'))
        ).toBe(false);
    });

    it('surfaces a server-side restore rejection message', async () => {
        const user = userEvent.setup();
        fetchMock.mockImplementation((url: string) => {
            if (url === INFO_URL) {
                return Promise.resolve(jsonResponse({ data: { attemptCount: 2 } }));
            }
            if (url === '/facilitator/api/v1/data/restore') {
                return Promise.resolve(jsonResponse({ message: 'Unsupported bundle version' }, false, 400));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        const input = document.getElementById('restoreFileInput') as HTMLInputElement;
        await user.upload(input, new File(['{}'], 'backup.json', { type: 'application/json' }));
        await user.click(screen.getByRole('button', { name: 'Restore from file' }));

        await waitFor(() =>
            expect(document.getElementById('restoreStatus')).toHaveTextContent(
                'Restore failed: Unsupported bundle version'
            )
        );
    });

    it('arms reset only for the literal word RESET and clears the input on success', async () => {
        const user = userEvent.setup();
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === INFO_URL) {
                return Promise.resolve(jsonResponse({ data: { attemptCount: 5 } }));
            }
            if (url === '/facilitator/api/v1/data/reset') {
                expect(options?.method).toBe('POST');
                expect(JSON.parse(String(options?.body))).toEqual({ confirm: 'RESET' });
                return Promise.resolve(jsonResponse({ data: {} }));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        const resetButton = screen.getByRole('button', { name: 'Reset attempt history' });
        expect(resetButton).toBeDisabled();

        const confirmInput = document.getElementById('resetConfirmInput') as HTMLInputElement;
        await user.type(confirmInput, 'reset');
        expect(resetButton).toBeDisabled();
        await user.clear(confirmInput);
        await user.type(confirmInput, 'RESET');
        expect(resetButton).toBeEnabled();

        await user.click(resetButton);
        await waitFor(() =>
            expect(document.getElementById('resetStatus')).toHaveTextContent(
                'Attempt history reset. A backup file was written first.'
            )
        );
        expect(confirmInput.value).toBe('');
        expect(resetButton).toBeDisabled();
    });

    it('shows the reset rejection message and keeps the arming input', async () => {
        const user = userEvent.setup();
        fetchMock.mockImplementation((url: string) => {
            if (url === INFO_URL) {
                return Promise.resolve(jsonResponse({ data: { attemptCount: 5 } }));
            }
            if (url === '/facilitator/api/v1/data/reset') {
                return Promise.resolve(jsonResponse({ message: 'Reset rejected' }, false, 400));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        const confirmInput = document.getElementById('resetConfirmInput') as HTMLInputElement;
        await user.type(confirmInput, 'RESET');
        await user.click(screen.getByRole('button', { name: 'Reset attempt history' }));

        await waitFor(() =>
            expect(document.getElementById('resetStatus')).toHaveTextContent(
                'Reset failed: Reset rejected'
            )
        );
        expect(confirmInput.value).toBe('RESET');
        expect(screen.getByRole('button', { name: 'Reset attempt history' })).toBeEnabled();
    });

    it('sets the legacy document title', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(jsonResponse({}, false, 500)));
        renderPage();
        await waitFor(() => expect(document.title).toBe('Settings & Local Data | CK-X'));
    });
});
