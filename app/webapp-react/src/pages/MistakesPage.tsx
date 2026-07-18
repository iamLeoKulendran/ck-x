import { useEffect, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { AppShell } from '@/components/shell/AppShell';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Chip } from '@/components/ui/chip';
import { API_BASE, apiData, patchJson, postJson } from '@/lib/api';
import { usePageTitle } from '@/lib/use-page-title';
import { cn } from '@/lib/utils';

// React port of mistakes.html + js/mistakes.js. Same query params
// (category/resolved), same PATCH/POST/DELETE endpoints, same chips,
// counters, retest queue and confirmation dialogs. Legacy ids kept for the
// Playwright baseline.

interface Retest {
    retestId: string;
    scheduledFor: string;
    result: 'pending' | 'passed' | 'failed';
}

interface Mistake {
    mistakeId: string;
    category: string;
    summary?: string;
    createdAt?: string;
    resolved: boolean;
    rootCauseNote?: string;
    correction: { status: 'none' | 'planned' | 'done'; note?: string };
    retests?: Retest[];
    source: {
        labId?: string;
        labName?: string;
        questionId?: string | number;
        certificationCode?: string;
        attemptId?: string | number;
    };
}

interface MistakesData {
    counts: { total: number; correctionDone: number; resolved: number; pendingRetests: number };
    retestQueue: { scheduledFor: string; summary: string }[];
    categories: string[];
    mistakes: Mistake[];
}

function formatDate(isoString?: string) {
    const date = new Date(isoString ?? '');
    return Number.isNaN(date.getTime()) ? String(isoString || '') : date.toLocaleDateString();
}

const selectClass =
    'rounded-ckx-sm border border-line-strong bg-surface-soft p-2 text-sm text-ink';
const inputClass =
    'rounded-ckx-sm border border-line-strong bg-surface-soft p-2 text-sm text-ink placeholder:text-ink-muted';

export function MistakesPage() {
    usePageTitle('Mistakes & Retests | CK-X');
    const queryClient = useQueryClient();
    const [category, setCategory] = useState('');
    const [resolved, setResolved] = useState('');
    // Legacy behavior: the category options are populated once from the
    // first successful load, so filtering never shrinks the option list.
    const [categories, setCategories] = useState<string[] | null>(null);
    const [notes, setNotes] = useState<Record<string, string>>({});
    const [retestDates, setRetestDates] = useState<Record<string, string>>({});
    // Legacy disables each clicked button independently, so overlapping
    // requests must not re-enable one another — track every pending key.
    const [busyActions, setBusyActions] = useState<string[]>([]);

    const query = useQuery({
        queryKey: ['mistakes', category, resolved],
        queryFn: async () => {
            const params = new URLSearchParams();
            if (category) params.set('category', category);
            if (resolved) params.set('resolved', resolved);
            const data = await apiData<MistakesData>(
                `${API_BASE}/mistakes?${params.toString()}`
            );
            return data;
        }
    });

    const loadedCategories = query.data?.categories;
    useEffect(() => {
        if (loadedCategories && categories === null) {
            setCategories(loadedCategories);
        }
    }, [loadedCategories, categories]);

    async function runAction(actionKey: string, request: () => Promise<unknown>) {
        setBusyActions((current) => [...current, actionKey]);
        try {
            await request();
            await queryClient.invalidateQueries({ queryKey: ['mistakes'] });
        } catch (error) {
            console.error('Mistake action failed:', error);
            alert(`Action failed: ${(error as Error).message}`);
        } finally {
            setBusyActions((current) => current.filter((key) => key !== actionKey));
        }
    }

    function correction(mistakeId: string, status: 'planned' | 'done') {
        const note = notes[mistakeId];
        return runAction(`correction-${status}-${mistakeId}`, () =>
            apiData(
                `${API_BASE}/mistakes/${mistakeId}/correction`,
                patchJson({ status, note: note || undefined })
            )
        );
    }

    function scheduleRetest(mistakeId: string) {
        const scheduledFor = retestDates[mistakeId];
        return runAction(`schedule-${mistakeId}`, () =>
            apiData(
                `${API_BASE}/mistakes/${mistakeId}/retests`,
                postJson({ scheduledFor: scheduledFor || undefined })
            )
        );
    }

    function recordRetestResult(mistakeId: string, retestId: string, result: 'passed' | 'failed') {
        return runAction(`retest-${retestId}-${result}`, () =>
            apiData(
                `${API_BASE}/mistakes/${mistakeId}/retests/${retestId}`,
                patchJson({ result })
            )
        );
    }

    function deleteMistake(mistakeId: string) {
        if (!window.confirm('Delete this mistake record? This cannot be undone from the UI.')) {
            return;
        }
        void runAction(`delete-${mistakeId}`, () =>
            apiData(`${API_BASE}/mistakes/${mistakeId}`, { method: 'DELETE' })
        );
    }

    const data = query.data;
    const today = new Date().toISOString().slice(0, 10);

    return (
        <AppShell activeHref="/mistakes.html">
            <header className="mb-8">
                <h1 className="text-3xl font-bold tracking-tight">Mistakes &amp; Retests</h1>
                <p className="mt-2 text-ink-secondary">
                    A mistake is resolved only when you completed a correction <em>and</em> the latest
                    retest passed. Logging one, fixing one, and re-proving one are tracked separately.
                </p>
            </header>

            {data ? (
                <div id="mistakeCounters" className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-4">
                    {[
                        { label: 'Captured mistakes', value: data.counts.total },
                        { label: 'Corrections done', value: data.counts.correctionDone },
                        { label: 'Resolved (corrected + retest passed)', value: data.counts.resolved },
                        { label: 'Retests pending', value: data.counts.pendingRetests }
                    ].map((card) => (
                        <Card key={card.label}>
                            <CardContent className="p-4">
                                <div className="text-2xl font-bold">{card.value}</div>
                                <div className="text-sm text-ink-muted">{card.label}</div>
                            </CardContent>
                        </Card>
                    ))}
                </div>
            ) : null}

            <Card aria-labelledby="retestQueueHeading" className="mb-5">
                <CardContent>
                    <h2 className="mb-3 text-lg font-semibold" id="retestQueueHeading">
                        Retest queue
                    </h2>
                    <div id="retestQueue">
                        {data ? (
                            data.retestQueue.length ? (
                                <ul className="flex flex-col gap-1.5">
                                    {data.retestQueue.map((entry, index) => (
                                        <li key={index} className="flex flex-wrap items-center gap-2 text-sm">
                                            {String(entry.scheduledFor) <= today ? (
                                                <Chip tone="warn">DUE</Chip>
                                            ) : (
                                                <Chip tone="muted">SCHEDULED</Chip>
                                            )}
                                            <span>
                                                {entry.scheduledFor} — {entry.summary}
                                            </span>
                                        </li>
                                    ))}
                                </ul>
                            ) : (
                                <p className="text-ink-muted">
                                    No retests scheduled. Schedule one from a mistake below.
                                </p>
                            )
                        ) : null}
                    </div>
                </CardContent>
            </Card>

            <div className="mb-5 flex flex-wrap items-center gap-3">
                <label className="text-sm font-medium" htmlFor="categoryFilter">
                    Category
                </label>
                <select
                    id="categoryFilter"
                    className={selectClass}
                    value={category}
                    onChange={(event) => setCategory(event.target.value)}
                >
                    <option value="">All</option>
                    {(categories ?? []).map((entry) => (
                        <option key={entry} value={entry}>
                            {entry}
                        </option>
                    ))}
                </select>
                <label className="text-sm font-medium" htmlFor="resolvedFilter">
                    Status
                </label>
                <select
                    id="resolvedFilter"
                    className={selectClass}
                    value={resolved}
                    onChange={(event) => setResolved(event.target.value)}
                >
                    <option value="">All</option>
                    <option value="false">Unresolved</option>
                    <option value="true">Resolved</option>
                </select>
            </div>

            <div
                id="mistakesStatus"
                role="status"
                className={cn('min-h-5 text-sm', query.isError ? 'text-bad' : 'text-ink-muted')}
            >
                {query.isLoading ? 'Loading mistakes…' : query.isError ? 'Failed to load mistakes.' : ''}
            </div>

            <div id="mistakesList" className="flex flex-col gap-4">
                {data ? (
                    data.mistakes.length ? (
                        data.mistakes.map((mistake) => (
                            <Card key={mistake.mistakeId} data-mistake-card={mistake.mistakeId}>
                                <CardContent>
                                    <div className="mb-3 flex flex-wrap items-center gap-2">
                                        {mistake.resolved ? (
                                            <Chip tone="good">RESOLVED</Chip>
                                        ) : (
                                            <Chip tone="bad">OPEN</Chip>
                                        )}
                                        {mistake.correction.status === 'none' ? (
                                            <Chip tone="muted">CORRECTION: NONE</Chip>
                                        ) : mistake.correction.status === 'planned' ? (
                                            <Chip tone="warn">CORRECTION: PLANNED</Chip>
                                        ) : (
                                            <Chip tone="good">CORRECTION: DONE</Chip>
                                        )}
                                        <Chip tone="muted">{mistake.category}</Chip>
                                        <span className="ml-auto text-xs text-ink-muted">
                                            captured {formatDate(mistake.createdAt)}
                                        </span>
                                    </div>
                                    <h2 className="mb-1 text-base font-semibold">
                                        {mistake.summary || 'Mistake'}
                                    </h2>
                                    <p className="mb-3 text-xs text-ink-muted">
                                        {[
                                            mistake.source.labName || mistake.source.labId,
                                            `Question ${mistake.source.questionId}`,
                                            mistake.source.certificationCode
                                        ]
                                            .filter(Boolean)
                                            .join(' · ')}{' '}
                                        · attempt {mistake.source.attemptId}
                                    </p>
                                    {mistake.rootCauseNote ? (
                                        <p className="mb-2 text-sm">
                                            <strong>Root cause:</strong> {mistake.rootCauseNote}
                                        </p>
                                    ) : null}
                                    {mistake.correction.note ? (
                                        <p className="mb-2 text-sm">
                                            <strong>Corrective action:</strong> {mistake.correction.note}
                                        </p>
                                    ) : null}

                                    <div className="mb-3 flex flex-wrap items-center gap-2">
                                        <input
                                            type="text"
                                            className={cn(inputClass, 'h-8 min-w-48 flex-1 py-1')}
                                            placeholder="Root cause / corrective action note"
                                            aria-label="Correction note"
                                            data-note-input={mistake.mistakeId}
                                            value={notes[mistake.mistakeId] ?? ''}
                                            onChange={(event) =>
                                                setNotes((current) => ({
                                                    ...current,
                                                    [mistake.mistakeId]: event.target.value
                                                }))
                                            }
                                        />
                                        <Button
                                            size="sm"
                                            variant="secondary"
                                            disabled={busyActions.includes(`correction-planned-${mistake.mistakeId}`)}
                                            onClick={() => correction(mistake.mistakeId, 'planned')}
                                        >
                                            Plan correction
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            disabled={busyActions.includes(`correction-done-${mistake.mistakeId}`)}
                                            onClick={() => correction(mistake.mistakeId, 'done')}
                                        >
                                            Mark correction done
                                        </Button>
                                    </div>

                                    <div className="mb-1 flex flex-wrap items-center gap-2">
                                        <label
                                            className="text-xs text-ink-secondary"
                                            htmlFor={`retest-date-${mistake.mistakeId}`}
                                        >
                                            Delayed retest date
                                        </label>
                                        <input
                                            type="date"
                                            className={cn(inputClass, 'h-8 py-1')}
                                            id={`retest-date-${mistake.mistakeId}`}
                                            value={retestDates[mistake.mistakeId] ?? ''}
                                            onChange={(event) =>
                                                setRetestDates((current) => ({
                                                    ...current,
                                                    [mistake.mistakeId]: event.target.value
                                                }))
                                            }
                                        />
                                        <Button
                                            size="sm"
                                            variant="secondary"
                                            disabled={busyActions.includes(`schedule-${mistake.mistakeId}`)}
                                            onClick={() => scheduleRetest(mistake.mistakeId)}
                                        >
                                            Schedule retest
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="danger"
                                            className="ml-auto"
                                            disabled={busyActions.includes(`delete-${mistake.mistakeId}`)}
                                            onClick={() => deleteMistake(mistake.mistakeId)}
                                        >
                                            Delete
                                        </Button>
                                    </div>

                                    {mistake.retests && mistake.retests.length ? (
                                        <>
                                            <h3 className="mt-4 text-sm font-semibold">Retests</h3>
                                            <ul className="mt-1 flex flex-col gap-1.5">
                                                {mistake.retests.map((retest) => (
                                                    <li
                                                        key={retest.retestId}
                                                        className="flex flex-wrap items-center gap-2 text-sm"
                                                    >
                                                        {retest.result === 'passed' ? (
                                                            <Chip tone="good">PASSED</Chip>
                                                        ) : retest.result === 'failed' ? (
                                                            <Chip tone="bad">FAILED</Chip>
                                                        ) : (
                                                            <Chip tone="muted">PENDING</Chip>
                                                        )}
                                                        <span>scheduled {retest.scheduledFor}</span>
                                                        {retest.result === 'pending' ? (
                                                            <>
                                                                <Button
                                                                    size="sm"
                                                                    variant="outline"
                                                                    disabled={busyActions.includes(
                                                                        `retest-${retest.retestId}-passed`
                                                                    )}
                                                                    onClick={() =>
                                                                        recordRetestResult(
                                                                            mistake.mistakeId,
                                                                            retest.retestId,
                                                                            'passed'
                                                                        )
                                                                    }
                                                                >
                                                                    Record pass
                                                                </Button>
                                                                <Button
                                                                    size="sm"
                                                                    variant="danger"
                                                                    disabled={busyActions.includes(
                                                                        `retest-${retest.retestId}-failed`
                                                                    )}
                                                                    onClick={() =>
                                                                        recordRetestResult(
                                                                            mistake.mistakeId,
                                                                            retest.retestId,
                                                                            'failed'
                                                                        )
                                                                    }
                                                                >
                                                                    Record fail
                                                                </Button>
                                                            </>
                                                        ) : null}
                                                    </li>
                                                ))}
                                            </ul>
                                        </>
                                    ) : null}
                                </CardContent>
                            </Card>
                        ))
                    ) : (
                        <div className="rounded-ckx border border-dashed border-line-strong bg-surface-soft p-6 text-center text-ink-muted">
                            No mistakes captured yet. After an exam, use &quot;Log mistake for review&quot; on
                            any failed question in the results page.
                        </div>
                    )
                ) : null}
            </div>
        </AppShell>
    );
}
