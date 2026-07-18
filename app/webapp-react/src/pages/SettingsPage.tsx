import { useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { AppShell } from '@/components/shell/AppShell';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { API_BASE, apiRaw, postJson } from '@/lib/api';
import { usePageTitle } from '@/lib/use-page-title';
import { cn } from '@/lib/utils';

// React port of settings.html + js/settings.js. Same endpoints, same
// arming rules (restore needs a file, reset needs the literal word RESET),
// same status strings. Element ids are kept so the Phase 0 Playwright
// baseline keeps its selectors.

interface DataInfo {
    historyFile?: string;
    historyVersion?: number | null;
    attemptCount?: number | null;
    telemetryEnabled?: boolean;
}

interface StatusLine {
    message: string;
    isError: boolean;
}

function StatusText({ id, status }: { id: string; status: StatusLine }) {
    return (
        <div
            id={id}
            role="status"
            className={cn(
                'mt-3 min-h-5 text-sm',
                status.isError && 'text-bad',
                !status.isError && status.message && 'text-good'
            )}
        >
            {status.message}
        </div>
    );
}

async function fetchDataInfo(): Promise<DataInfo> {
    const response = await fetch(`${API_BASE}/data/info`);
    if (!response.ok) {
        throw new Error('Status ' + response.status);
    }
    const payload = await response.json();
    return (payload.data || {}) as DataInfo;
}

export function SettingsPage() {
    usePageTitle('Settings & Local Data | CK-X');
    const queryClient = useQueryClient();
    const info = useQuery({ queryKey: ['data-info'], queryFn: fetchDataInfo });

    const restoreFileRef = useRef<HTMLInputElement>(null);
    const [restoreFileSelected, setRestoreFileSelected] = useState(false);
    const [restoreBusy, setRestoreBusy] = useState(false);
    const [restoreStatus, setRestoreStatus] = useState<StatusLine>({ message: '', isError: false });

    const [resetConfirm, setResetConfirm] = useState('');
    const [resetBusy, setResetBusy] = useState(false);
    const [resetStatus, setResetStatus] = useState<StatusLine>({ message: '', isError: false });

    const infoValue = (value: string | undefined) =>
        info.isError ? 'Unavailable' : info.isLoading ? 'Loading…' : (value ?? 'Unknown');

    const data = info.data;

    async function handleRestore() {
        const file = restoreFileRef.current?.files?.[0];
        if (!file) {
            return;
        }
        setRestoreBusy(true);
        setRestoreStatus({ message: 'Restoring…', isError: false });
        try {
            const text = await file.text();
            let bundle: unknown;
            try {
                bundle = JSON.parse(text);
            } catch {
                throw new Error('The selected file is not valid JSON');
            }
            const { ok, payload } = await apiRaw(`${API_BASE}/data/restore`, postJson(bundle));
            if (!ok) {
                throw new Error(payload.message || 'Restore rejected');
            }
            setRestoreStatus({
                message: `Restored ${payload.data?.attemptCount} attempts. Previous file was backed up.`,
                isError: false
            });
            queryClient.invalidateQueries({ queryKey: ['data-info'] });
        } catch (error) {
            console.error('Restore failed:', error);
            setRestoreStatus({
                message: `Restore failed: ${(error as Error).message}`,
                isError: true
            });
        } finally {
            setRestoreBusy(false);
        }
    }

    async function handleReset() {
        setResetBusy(true);
        setResetStatus({ message: 'Resetting…', isError: false });
        try {
            const { ok, payload } = await apiRaw(`${API_BASE}/data/reset`, postJson({ confirm: 'RESET' }));
            if (!ok) {
                throw new Error(payload.message || 'Reset rejected');
            }
            setResetStatus({
                message: 'Attempt history reset. A backup file was written first.',
                isError: false
            });
            setResetConfirm('');
            queryClient.invalidateQueries({ queryKey: ['data-info'] });
        } catch (error) {
            console.error('Reset failed:', error);
            setResetStatus({ message: `Reset failed: ${(error as Error).message}`, isError: true });
        } finally {
            setResetBusy(false);
        }
    }

    return (
        <AppShell activeHref="/settings.html">
            <header className="mb-8">
                <h1 className="text-3xl font-bold tracking-tight">Settings &amp; Local Data</h1>
                <p className="mt-2 text-ink-secondary">
                    All CK-X data lives on this machine. Back it up, restore it, or reset it here.
                </p>
            </header>

            <div className="flex flex-col gap-5">
                <Card aria-labelledby="dataInfoHeading">
                    <CardContent>
                        <h2 className="mb-4 text-lg font-semibold" id="dataInfoHeading">
                            Local data
                        </h2>
                        <dl className="grid grid-cols-1 gap-x-6 gap-y-2 sm:grid-cols-[minmax(9rem,auto)_1fr]">
                            <dt className="font-medium text-ink-secondary">History file</dt>
                            <dd id="infoHistoryFile" className="break-all">
                                {infoValue(data?.historyFile || 'Unknown')}
                            </dd>
                            <dt className="font-medium text-ink-secondary">Schema version</dt>
                            <dd id="infoHistoryVersion">
                                {infoValue(data?.historyVersion != null ? `v${data.historyVersion}` : 'Unknown')}
                            </dd>
                            <dt className="font-medium text-ink-secondary">Stored attempts</dt>
                            <dd id="infoAttemptCount">
                                {infoValue(data?.attemptCount != null ? String(data.attemptCount) : 'Unknown')}
                            </dd>
                            <dt className="font-medium text-ink-secondary">Telemetry</dt>
                            <dd id="infoTelemetry">
                                {infoValue(
                                    data
                                        ? data.telemetryEnabled
                                            ? 'Enabled (TRACK_METRICS=true)'
                                            : 'Disabled (local-only, default)'
                                        : 'Unknown'
                                )}
                            </dd>
                        </dl>
                    </CardContent>
                </Card>

                <Card aria-labelledby="backupHeading">
                    <CardContent>
                        <h2 className="mb-2 text-lg font-semibold" id="backupHeading">
                            Backup
                        </h2>
                        <p className="mb-4 text-ink-secondary">
                            Download every stored attempt as a JSON bundle. Keep it anywhere; restore it below
                            later.
                        </p>
                        {/* Plain anchor download, exactly like the legacy page */}
                        <a
                            className="inline-flex h-10 items-center justify-center rounded-ckx-sm bg-primary px-4 text-sm font-medium text-white shadow-ckx-sm hover:bg-primary-active"
                            href={`${API_BASE}/data/export`}
                            download
                        >
                            Download backup
                        </a>
                    </CardContent>
                </Card>

                <Card aria-labelledby="restoreHeading">
                    <CardContent>
                        <h2 className="mb-2 text-lg font-semibold" id="restoreHeading">
                            Restore
                        </h2>
                        <p className="mb-4 text-ink-secondary">
                            Replace the current attempt history with a previously exported bundle. The current
                            file is backed up automatically before anything is written.
                        </p>
                        <input
                            ref={restoreFileRef}
                            type="file"
                            id="restoreFileInput"
                            accept="application/json"
                            aria-label="Backup bundle file"
                            className="mb-4 block w-full cursor-pointer rounded-ckx-sm border border-line-strong bg-surface-soft p-2 text-sm text-ink-secondary file:mr-3 file:rounded-ckx-sm file:border-0 file:bg-surface-raised file:px-3 file:py-1.5 file:text-ink"
                            onChange={(event) => {
                                setRestoreFileSelected(Boolean(event.target.files?.length));
                                setRestoreStatus({ message: '', isError: false });
                            }}
                        />
                        <Button
                            id="restoreBtn"
                            variant="secondary"
                            disabled={!restoreFileSelected || restoreBusy}
                            onClick={handleRestore}
                        >
                            Restore from file
                        </Button>
                        <StatusText id="restoreStatus" status={restoreStatus} />
                    </CardContent>
                </Card>

                <Card aria-labelledby="resetHeading" className="border-bad">
                    <CardContent>
                        <h2 className="mb-2 text-lg font-semibold text-bad" id="resetHeading">
                            Reset
                        </h2>
                        <p className="mb-4 text-ink-secondary">
                            Delete all stored attempts. A backup file is written next to the history file
                            first, but the UI will show an empty history afterwards.
                        </p>
                        <label className="mb-1 block text-sm font-medium" htmlFor="resetConfirmInput">
                            Type <code className="rounded bg-surface-soft px-1.5 py-0.5">RESET</code> to enable
                            the button:
                        </label>
                        <input
                            type="text"
                            id="resetConfirmInput"
                            autoComplete="off"
                            aria-describedby="resetHeading"
                            className="mb-4 block w-full rounded-ckx-sm border border-line-strong bg-surface-soft p-2 text-sm text-ink"
                            value={resetConfirm}
                            onChange={(event) => setResetConfirm(event.target.value)}
                        />
                        <Button
                            id="resetBtn"
                            variant="danger"
                            disabled={resetConfirm !== 'RESET' || resetBusy}
                            onClick={handleReset}
                        >
                            Reset attempt history
                        </Button>
                        <StatusText id="resetStatus" status={resetStatus} />
                    </CardContent>
                </Card>
            </div>
        </AppShell>
    );
}
