import { useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { AppShell } from '@/components/shell/AppShell';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Chip } from '@/components/ui/chip';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow
} from '@/components/ui/table';
import { API_BASE, apiRaw, postJson } from '@/lib/api';
import { usePageTitle } from '@/lib/use-page-title';
import { cn } from '@/lib/utils';

// React port of packs.html + js/packs.js: pack list with export/delete,
// bundle import (with the performance-pack confirmation), and the MCQ
// builder with validate / save / download. Same endpoints, same messages,
// same window.confirm flows; legacy element ids kept for the Playwright
// baseline selectors.

interface Pack {
    id: string;
    name: string;
    category: string;
    examType?: string;
    questionCount?: number | null;
    imported?: boolean;
}

interface StatusLine {
    message: string;
    isError: boolean;
}

interface BuilderOption {
    text: string;
    correct: boolean;
}

interface BuilderQuestion {
    key: number;
    question: string;
    weightage: string;
    domain: string;
    concepts: string;
    explanation: string;
    options: BuilderOption[];
}

let builderKey = 0;

function emptyQuestion(): BuilderQuestion {
    builderKey += 1;
    return {
        key: builderKey,
        question: '',
        weightage: '',
        domain: '',
        concepts: '',
        explanation: '',
        options: [0, 1, 2, 3].map(() => ({ text: '', correct: false }))
    };
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

function ErrorList({ id, errors }: { id: string; errors: string[] }) {
    return (
        <ul id={id} className="mt-1 list-disc pl-5 text-sm text-bad">
            {errors.map((error, index) => (
                <li key={index}>{error}</li>
            ))}
        </ul>
    );
}

async function fetchPacks(): Promise<Pack[]> {
    const response = await fetch(`${API_BASE}/packs`);
    const payload = await response.json();
    return (payload.data.packs || []) as Pack[];
}

export function PacksPage() {
    usePageTitle('Question Packs | CK-X');
    const queryClient = useQueryClient();
    const packs = useQuery({ queryKey: ['packs'], queryFn: fetchPacks });

    const importFileRef = useRef<HTMLInputElement>(null);
    const [importFileSelected, setImportFileSelected] = useState(false);
    const [importBusy, setImportBusy] = useState(false);
    const [importStatus, setImportStatus] = useState<StatusLine>({ message: '', isError: false });
    const [importErrors, setImportErrors] = useState<string[]>([]);

    const [builderPackId, setBuilderPackId] = useState('');
    const [builderPackName, setBuilderPackName] = useState('');
    const [builderCategory, setBuilderCategory] = useState('KCNA');
    const [builderDuration, setBuilderDuration] = useState('30');
    // Start with two empty questions to make the shape obvious (legacy parity)
    const [questions, setQuestions] = useState<BuilderQuestion[]>(() => [
        emptyQuestion(),
        emptyQuestion()
    ]);
    const [builderStatus, setBuilderStatus] = useState<StatusLine>({ message: '', isError: false });
    const [builderErrors, setBuilderErrors] = useState<string[]>([]);
    const [downloadHref, setDownloadHref] = useState('#');
    const [downloadName, setDownloadName] = useState('ckx-pack-draft.json');

    const totalWeight = questions.reduce(
        (sum, question) => sum + (Number(question.weightage) || 0),
        0
    );

    function updateQuestion(key: number, patch: Partial<BuilderQuestion>) {
        setQuestions((current) =>
            current.map((question) => (question.key === key ? { ...question, ...patch } : question))
        );
    }

    function updateOption(key: number, optionIndex: number, patch: Partial<BuilderOption>) {
        setQuestions((current) =>
            current.map((question) =>
                question.key === key
                    ? {
                          ...question,
                          options: question.options.map((option, index) =>
                              index === optionIndex ? { ...option, ...patch } : option
                          )
                      }
                    : question
            )
        );
    }

    function collectBuilderBundle() {
        const bundleQuestions = questions.map((card, index) => {
            const options = card.options
                .map((option) => ({ text: option.text.trim(), correct: option.correct }))
                .filter((option) => option.text.length > 0);

            return {
                id: String(index + 1),
                type: 'multiple-choice',
                domain: card.domain.trim() || undefined,
                concepts: card.concepts
                    .split(',')
                    .map((entry) => entry.trim())
                    .filter(Boolean),
                question: card.question.trim(),
                options: options.map((option) => option.text),
                correctOptionIndexes: options
                    .map((option, optionIndex) => (option.correct ? optionIndex : null))
                    .filter((optionIndex): optionIndex is number => optionIndex !== null),
                weightage: Number(card.weightage) || 0,
                explanation: card.explanation.trim()
            };
        });

        return {
            packFormatVersion: 1,
            lab: {
                id: builderPackId.trim(),
                name: builderPackName.trim(),
                category: builderCategory,
                description: `Community-authored ${builderCategory} multiple-choice pack.`,
                difficulty: 'Medium',
                examDurationInMinutes: Number(builderDuration) || 30,
                certificationCode: builderCategory === 'Other' ? undefined : builderCategory
            },
            config: {
                examType: 'mcq',
                totalMarks: 100,
                lowScore: 50,
                mediumScore: 75,
                highScore: 90
            },
            assessment: { questions: bundleQuestions },
            answersMarkdown:
                '# Answers\n\n' +
                bundleQuestions
                    .map(
                        (question) =>
                            `## Question ${question.id}\n**Correct option index(es):** ${question.correctOptionIndexes.join(', ')}\n\n${question.explanation}\n`
                    )
                    .join('\n'),
            scripts: { setup: {}, validation: {} }
        };
    }

    async function handleDeletePack(packId: string) {
        if (
            !window.confirm(
                `Delete imported pack "${packId}" and its files? This cannot be undone from the UI.`
            )
        ) {
            return;
        }
        try {
            const response = await fetch(`${API_BASE}/packs/${encodeURIComponent(packId)}`, {
                method: 'DELETE'
            });
            await response.json();
            queryClient.invalidateQueries({ queryKey: ['packs'] });
        } catch (error) {
            alert(`Delete failed: ${(error as Error).message}`);
        }
    }

    async function handleImport() {
        const file = importFileRef.current?.files?.[0];
        if (!file) {
            return;
        }
        setImportBusy(true);
        setImportStatus({ message: 'Validating…', isError: false });
        setImportErrors([]);
        try {
            const text = await file.text();
            let bundle: { config?: { examType?: string } };
            try {
                bundle = JSON.parse(text);
            } catch {
                throw new Error('The selected file is not valid JSON');
            }

            const isPerformance = !bundle.config || bundle.config.examType !== 'mcq';
            if (isPerformance) {
                const confirmed = window.confirm(
                    'This is a PERFORMANCE pack: its shell scripts will execute inside the CK-X exam sandbox ' +
                        '(jumphost and practice cluster) whenever this lab runs.\n\n' +
                        'Only continue if you trust the pack author. Import now?'
                );
                if (!confirmed) {
                    throw new Error('Import cancelled');
                }
            }

            const { ok, payload } = await apiRaw(`${API_BASE}/packs/import`, postJson(bundle));
            if (!ok) {
                setImportErrors(payload.errors || [payload.message || payload.error || 'Import rejected']);
                throw new Error(payload.error || 'Import rejected');
            }
            setImportStatus({
                message: `Imported "${payload.data?.packId}". It now appears in the lab list on the home page.`,
                isError: false
            });
            queryClient.invalidateQueries({ queryKey: ['packs'] });
        } catch (error) {
            setImportStatus({ message: (error as Error).message, isError: true });
        } finally {
            setImportBusy(false);
        }
    }

    async function submitBuilderBundle(validateOnly: boolean) {
        const bundle = collectBuilderBundle();
        setBuilderStatus({ message: validateOnly ? 'Validating…' : 'Saving…', isError: false });
        setBuilderErrors([]);

        try {
            const { ok, payload } = await apiRaw(
                `${API_BASE}/packs/import?validateOnly=${validateOnly}`,
                postJson(bundle)
            );
            if (validateOnly) {
                if (payload.data && payload.data.valid) {
                    setBuilderStatus({ message: 'Bundle is valid.', isError: false });
                } else {
                    setBuilderErrors((payload.data && payload.data.errors) || payload.errors || []);
                    setBuilderStatus({ message: 'Validation failed.', isError: true });
                }
                return;
            }
            if (!ok) {
                setBuilderErrors(payload.errors || []);
                throw new Error(payload.error || 'Save rejected');
            }
            setBuilderStatus({
                message: `Pack "${payload.data?.packId}" saved. It now appears in the lab list.`,
                isError: false
            });
            queryClient.invalidateQueries({ queryKey: ['packs'] });
        } catch (error) {
            setBuilderStatus({ message: (error as Error).message, isError: true });
        }
    }

    function handleDownload(event: React.MouseEvent<HTMLAnchorElement>) {
        const bundle = collectBuilderBundle();
        const blob = new Blob([JSON.stringify(bundle, null, 2)], { type: 'application/json' });
        const href = URL.createObjectURL(blob);
        const name = `ckx-pack-${bundle.lab.id || 'draft'}.json`;
        // Like the legacy page, the href/download are set synchronously in
        // the click handler so the default navigation downloads THIS bundle.
        event.currentTarget.href = href;
        event.currentTarget.setAttribute('download', name);
        setDownloadHref(href);
        setDownloadName(name);
    }

    const inputClass =
        'block w-full rounded-ckx-sm border border-line-strong bg-surface-soft p-2 text-sm text-ink placeholder:text-ink-muted';

    return (
        <AppShell activeHref="/packs.html">
            <header className="mb-8">
                <h1 className="text-3xl font-bold tracking-tight">Question Packs</h1>
                <p className="mt-2 text-ink-secondary">
                    Export any lab as a shareable JSON pack, import community packs, or build a
                    multiple-choice pack in the browser. Performance-lab authoring stays file-based (see{' '}
                    <code className="rounded bg-surface-soft px-1.5 py-0.5">
                        docs/cka-lab-generation-guide.md
                    </code>
                    ).
                </p>
            </header>

            <div className="flex flex-col gap-5">
                <Card aria-labelledby="packListHeading">
                    <CardContent>
                        <h2 className="mb-3 text-lg font-semibold" id="packListHeading">
                            Installed packs
                        </h2>
                        <div id="packsStatus" role="status" className="min-h-5 text-sm text-ink-muted">
                            {packs.isLoading
                                ? 'Loading packs…'
                                : packs.isError
                                  ? 'Failed to load packs.'
                                  : ''}
                        </div>
                        {packs.isError ? null : packs.data ? (
                            <Table id="packsTable">
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>ID</TableHead>
                                        <TableHead>Name</TableHead>
                                        <TableHead>Category</TableHead>
                                        <TableHead>Type</TableHead>
                                        <TableHead>Questions</TableHead>
                                        <TableHead>Source</TableHead>
                                        <TableHead>Actions</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody id="packsTableBody">
                                    {packs.data.map((pack) => (
                                        <TableRow key={pack.id}>
                                            <TableCell>
                                                <code className="rounded bg-surface-soft px-1.5 py-0.5 text-xs">
                                                    {pack.id}
                                                </code>
                                            </TableCell>
                                            <TableCell className="text-ink">{pack.name}</TableCell>
                                            <TableCell>{pack.category}</TableCell>
                                            <TableCell>
                                                {pack.examType === 'mcq'
                                                    ? 'Multiple choice'
                                                    : 'Performance (lab)'}
                                            </TableCell>
                                            <TableCell>
                                                {pack.questionCount != null ? pack.questionCount : '—'}
                                            </TableCell>
                                            <TableCell>
                                                {pack.imported ? (
                                                    <Chip tone="warn">imported</Chip>
                                                ) : (
                                                    <Chip tone="muted">built-in</Chip>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <span className="flex items-center gap-2">
                                                    <a
                                                        className="inline-flex h-8 items-center rounded-ckx-sm border border-primary-border px-3 text-sm font-medium text-primary-ink hover:bg-primary-soft"
                                                        href={`${API_BASE}/packs/${encodeURIComponent(pack.id)}/export`}
                                                        download
                                                    >
                                                        Export
                                                    </a>
                                                    {pack.imported ? (
                                                        <Button
                                                            size="sm"
                                                            variant="danger"
                                                            data-delete-pack={pack.id}
                                                            onClick={() => handleDeletePack(pack.id)}
                                                        >
                                                            Delete
                                                        </Button>
                                                    ) : null}
                                                </span>
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        ) : null}
                    </CardContent>
                </Card>

                <Card aria-labelledby="importHeading">
                    <CardContent>
                        <h2 className="mb-2 text-lg font-semibold" id="importHeading">
                            Import a pack
                        </h2>
                        <p className="mb-3 text-ink-secondary">
                            Select a{' '}
                            <code className="rounded bg-surface-soft px-1.5 py-0.5">ckx-pack-*.json</code>{' '}
                            bundle. It is validated before anything is written: schema, marks sum, script
                            references, file-name safety, size limits, and duplicate ids.
                        </p>
                        <div
                            role="alert"
                            className="mb-4 rounded-ckx border border-warn bg-warn-soft p-4 text-sm text-ink"
                        >
                            <strong>Security note:</strong> performance packs contain shell scripts that will
                            run inside the CK-X exam sandbox (jumphost and practice cluster) when you start
                            the lab. They never run on your host machine or at import time. Only import packs
                            from sources you trust.
                        </div>
                        <input
                            ref={importFileRef}
                            type="file"
                            id="importFileInput"
                            accept="application/json"
                            aria-label="Pack bundle file"
                            className="mb-4 block w-full cursor-pointer rounded-ckx-sm border border-line-strong bg-surface-soft p-2 text-sm text-ink-secondary file:mr-3 file:rounded-ckx-sm file:border-0 file:bg-surface-raised file:px-3 file:py-1.5 file:text-ink"
                            onChange={(event) => {
                                setImportFileSelected(Boolean(event.target.files?.length));
                                setImportStatus({ message: '', isError: false });
                                setImportErrors([]);
                            }}
                        />
                        <Button
                            id="importBtn"
                            disabled={!importFileSelected || importBusy}
                            onClick={handleImport}
                        >
                            Validate &amp; import
                        </Button>
                        <StatusText id="importStatus" status={importStatus} />
                        <ErrorList id="importErrors" errors={importErrors} />
                    </CardContent>
                </Card>

                <Card aria-labelledby="builderHeading">
                    <CardContent>
                        <h2 className="mb-2 text-lg font-semibold" id="builderHeading">
                            Build a multiple-choice pack
                        </h2>
                        <p className="mb-4 text-ink-secondary">
                            Author an original MCQ pack (KCNA/KCSA style). Weights must sum to 100. Never copy
                            real exam questions.
                        </p>

                        <div className="mb-4 grid grid-cols-1 gap-3 md:grid-cols-[1fr_1.4fr_0.8fr_1fr]">
                            <div>
                                <label className="mb-1 block text-sm font-medium" htmlFor="builderPackId">
                                    Pack id
                                </label>
                                <input
                                    type="text"
                                    id="builderPackId"
                                    className={inputClass}
                                    placeholder="kcna-my-pack-1"
                                    pattern="[a-z0-9-]+"
                                    value={builderPackId}
                                    onChange={(event) => setBuilderPackId(event.target.value)}
                                />
                            </div>
                            <div>
                                <label className="mb-1 block text-sm font-medium" htmlFor="builderPackName">
                                    Name
                                </label>
                                <input
                                    type="text"
                                    id="builderPackName"
                                    className={inputClass}
                                    placeholder="My KCNA Practice Pack"
                                    value={builderPackName}
                                    onChange={(event) => setBuilderPackName(event.target.value)}
                                />
                            </div>
                            <div>
                                <label className="mb-1 block text-sm font-medium" htmlFor="builderCategory">
                                    Category
                                </label>
                                <select
                                    id="builderCategory"
                                    className={inputClass}
                                    value={builderCategory}
                                    onChange={(event) => setBuilderCategory(event.target.value)}
                                >
                                    <option value="KCNA">KCNA</option>
                                    <option value="KCSA">KCSA</option>
                                    <option value="Other">Other</option>
                                </select>
                            </div>
                            <div>
                                <label className="mb-1 block text-sm font-medium" htmlFor="builderDuration">
                                    Duration (minutes)
                                </label>
                                <input
                                    type="number"
                                    id="builderDuration"
                                    className={inputClass}
                                    min={5}
                                    max={180}
                                    value={builderDuration}
                                    onChange={(event) => setBuilderDuration(event.target.value)}
                                />
                            </div>
                        </div>

                        <div id="builderQuestions" className="flex flex-col gap-4">
                            {questions.map((question, questionIndex) => (
                                <Card key={question.key} data-builder-question={question.key}>
                                    <CardContent>
                                        <div className="mb-3 flex items-center">
                                            <h3 className="text-base font-semibold">Question</h3>
                                            <Button
                                                size="sm"
                                                variant="danger"
                                                className="ml-auto"
                                                onClick={() =>
                                                    setQuestions((current) =>
                                                        current.filter((entry) => entry.key !== question.key)
                                                    )
                                                }
                                            >
                                                Remove
                                            </Button>
                                        </div>
                                        <textarea
                                            className={cn(inputClass, 'mb-3')}
                                            rows={2}
                                            placeholder="Question text"
                                            aria-label="Question text"
                                            value={question.question}
                                            onChange={(event) =>
                                                updateQuestion(question.key, { question: event.target.value })
                                            }
                                        />
                                        <div className="mb-3 grid grid-cols-1 gap-2 md:grid-cols-[0.6fr_1fr_1.4fr]">
                                            <input
                                                type="number"
                                                className={inputClass}
                                                placeholder="Weight"
                                                min={1}
                                                max={100}
                                                aria-label="Question weight"
                                                value={question.weightage}
                                                onChange={(event) =>
                                                    updateQuestion(question.key, {
                                                        weightage: event.target.value
                                                    })
                                                }
                                            />
                                            <input
                                                type="text"
                                                className={inputClass}
                                                placeholder="Domain id (optional)"
                                                aria-label="Domain id"
                                                value={question.domain}
                                                onChange={(event) =>
                                                    updateQuestion(question.key, { domain: event.target.value })
                                                }
                                            />
                                            <input
                                                type="text"
                                                className={inputClass}
                                                placeholder="Concepts, comma separated"
                                                aria-label="Concepts"
                                                value={question.concepts}
                                                onChange={(event) =>
                                                    updateQuestion(question.key, {
                                                        concepts: event.target.value
                                                    })
                                                }
                                            />
                                        </div>
                                        <div className="flex flex-col gap-1.5">
                                            {question.options.map((option, optionIndex) => (
                                                <div key={optionIndex} className="flex items-center gap-2">
                                                    <input
                                                        type="checkbox"
                                                        aria-label={`Option ${optionIndex + 1} is correct`}
                                                        checked={option.correct}
                                                        onChange={(event) =>
                                                            updateOption(question.key, optionIndex, {
                                                                correct: event.target.checked
                                                            })
                                                        }
                                                    />
                                                    <input
                                                        type="text"
                                                        className={cn(inputClass, 'h-8 py-1')}
                                                        placeholder={`Option ${optionIndex + 1}${optionIndex < 2 ? '' : ' (optional)'}`}
                                                        aria-label={`Option ${optionIndex + 1} text`}
                                                        value={option.text}
                                                        onChange={(event) =>
                                                            updateOption(question.key, optionIndex, {
                                                                text: event.target.value
                                                            })
                                                        }
                                                    />
                                                </div>
                                            ))}
                                        </div>
                                        <p className="mt-2 text-xs text-ink-muted">
                                            Tick the checkbox next to every correct option.
                                        </p>
                                        <textarea
                                            className={cn(inputClass, 'mt-2')}
                                            rows={2}
                                            placeholder="Explanation shown after evaluation"
                                            aria-label="Explanation"
                                            value={question.explanation}
                                            onChange={(event) =>
                                                updateQuestion(question.key, {
                                                    explanation: event.target.value
                                                })
                                            }
                                        />
                                        <span className="sr-only">Question {questionIndex + 1}</span>
                                    </CardContent>
                                </Card>
                            ))}
                        </div>

                        <div className="mt-4 flex flex-wrap items-center gap-2">
                            <Button
                                id="addQuestionBtn"
                                variant="secondary"
                                onClick={() => setQuestions((current) => [...current, emptyQuestion()])}
                            >
                                Add question
                            </Button>
                            <span
                                id="builderWeightNote"
                                className={cn(
                                    'text-sm',
                                    totalWeight !== 100 ? 'text-bad' : 'text-ink-muted'
                                )}
                            >
                                Total weight: {totalWeight} / 100
                            </span>
                            <Button
                                id="builderValidateBtn"
                                variant="outline"
                                className="ml-auto"
                                onClick={() => submitBuilderBundle(true)}
                            >
                                Validate
                            </Button>
                            <Button id="builderImportBtn" onClick={() => submitBuilderBundle(false)}>
                                Save as pack
                            </Button>
                            <a
                                id="builderDownloadBtn"
                                className="inline-flex h-10 items-center justify-center rounded-ckx-sm border border-line-strong bg-surface-raised px-4 text-sm font-medium text-ink hover:border-ink-muted"
                                download={downloadName}
                                href={downloadHref}
                                onClick={handleDownload}
                            >
                                Download bundle
                            </a>
                        </div>
                        <StatusText id="builderStatus" status={builderStatus} />
                        <ErrorList id="builderErrors" errors={builderErrors} />
                    </CardContent>
                </Card>
            </div>
        </AppShell>
    );
}
