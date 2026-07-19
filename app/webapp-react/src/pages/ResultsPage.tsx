import { useEffect, useRef, useState } from 'react';
import {
    CheckCircle2,
    XCircle,
    Home,
    ListTodo,
    CheckSquare,
    RefreshCw,
    Power
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { API_BASE } from '@/lib/api';
import { getQueryParam, navigate, openInNewTab } from '@/lib/navigation';
import { usePageTitle } from '@/lib/use-page-title';
import { cn } from '@/lib/utils';

// React port of results.html + js/results.js. Same endpoints, same 2s
// evaluation polling with a 100s cap, same error strings, same
// log-mistake payload. Legacy ids kept for the Playwright baseline.

const POLLING_INTERVAL = 2000;
const MAX_POLLING_TIME = 100000;

interface VerificationResult {
    id: string;
    description?: string;
    validAnswer: boolean;
    score: number;
    weightage: number;
}

interface EvaluationQuestion {
    id: string;
    concepts?: string[];
    verificationResults: VerificationResult[];
}

interface ExamResults {
    examId: string;
    completedAt: string;
    totalScore: number;
    totalPossibleScore: number;
    rank: 'high' | 'medium' | 'low' | string;
    evaluationResults?: EvaluationQuestion[];
}

interface ThresholdInfo {
    verdict: 'PASS' | 'BELOW THRESHOLD';
    detail: string;
}

interface AttemptRecord {
    attemptId?: string;
    examSessionId?: string;
    labId?: string;
    labName?: string;
    certificationCode?: string | null;
}

function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString(undefined, {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function sortById<T extends { id: string }>(items: T[]): T[] {
    return [...items].sort((a, b) => parseInt(a.id) - parseInt(b.id));
}

type PageState =
    | { kind: 'loading'; message: string }
    | { kind: 'error'; message: string }
    | { kind: 'ready'; results: ExamResults };

export function ResultsPage() {
    usePageTitle('Results | CK-X');
    const [state, setState] = useState<PageState>({
        kind: 'loading',
        message: 'Loading exam results...'
    });
    const [threshold, setThreshold] = useState<ThresholdInfo | null>(null);
    const [terminateOpen, setTerminateOpen] = useState(false);
    const [terminating, setTerminating] = useState(false);
    const [reEvaluating, setReEvaluating] = useState(false);
    const examIdRef = useRef<string | null>(null);
    const pollTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
    const pollStartRef = useRef(0);
    const unmountedRef = useRef(false);

    function stopPolling() {
        if (pollTimerRef.current) {
            clearInterval(pollTimerRef.current);
            pollTimerRef.current = null;
        }
    }

    function showError(message: string) {
        stopPolling();
        setState({ kind: 'error', message });
    }

    function startPolling(examId: string) {
        if (unmountedRef.current) return;
        pollStartRef.current = Date.now();
        setState({
            kind: 'loading',
            message: 'Evaluation in progress... (typically takes 2-3 minutes)'
        });
        stopPolling();
        pollTimerRef.current = setInterval(() => {
            void checkExamStatus(examId);
        }, POLLING_INTERVAL);
    }

    async function checkExamStatus(examId: string) {
        if (Date.now() - pollStartRef.current > MAX_POLLING_TIME) {
            stopPolling();
            showError('Exam evaluation is taking longer than expected. Please try again later.');
            return;
        }
        try {
            const response = await fetch(`${API_BASE}/exams/${examId}/status`);
            if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
            const data = (await response.json()) as { status?: string };
            // A response that lands after polling stopped is stale — acting
            // on it could hide already-rendered results (the legacy page only
            // ever swapped loader text, so it was immune to this race).
            if (!pollTimerRef.current) return;
            if (data.status === 'EVALUATED') {
                stopPolling();
                void fetchExamResults(examId);
            } else if (data.status === 'EVALUATING') {
                setState({
                    kind: 'loading',
                    message: 'Evaluation in progress... (typically takes 2-3 minutes)'
                });
            } else if (data.status === 'EVALUATION_FAILED') {
                stopPolling();
                showError('Exam evaluation failed. Please contact support.');
            } else {
                setState({
                    kind: 'loading',
                    message: `Waiting for evaluation to start... Current status: ${data.status}`
                });
            }
        } catch (error) {
            // Network errors do not stop polling — retry on the next tick
            console.error('Error checking exam status:', error);
        }
    }

    async function checkResultsStatus(examId: string) {
        const response = await fetch(`${API_BASE}/exams/${examId}/status`);
        if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
        const data = (await response.json()) as { status?: string };
        if (data.status === 'EVALUATING') {
            startPolling(examId);
        } else if (data.status === 'EVALUATION_FAILED') {
            throw new Error('Exam evaluation failed');
        } else if (data.status !== 'EVALUATED') {
            throw new Error(`Exam results not available. Current status: ${data.status}`);
        } else {
            // EVALUATED but result 404 — results may still be finalizing
            startPolling(examId);
        }
    }

    async function renderPassThreshold(results: ExamResults, examId: string) {
        const totalPossible = Number(results.totalPossibleScore) || 0;
        if (totalPossible <= 0) return;
        const percentage = ((Number(results.totalScore) || 0) / totalPossible) * 100;
        try {
            const [certResponse, currentResponse] = await Promise.all([
                fetch(`${API_BASE}/certifications`),
                fetch(`${API_BASE}/exams/current`)
            ]);
            const certData = certResponse.ok
                ? ((await certResponse.json()) as {
                      certifications?: {
                          code: string;
                          passThresholdPercent?: number;
                          blueprint?: { version?: string };
                      }[];
                  })
                : null;
            const currentExam = currentResponse.ok
                ? ((await currentResponse.json()) as {
                      id?: string;
                      info?: { category?: string };
                  })
                : null;
            if (!certData || !currentExam || !currentExam.info) return;
            // Only annotate when the active session matches this results page
            if (examId && currentExam.id !== examId) return;
            const category = currentExam.info.category;
            const profile = (certData.certifications || []).find((cert) => cert.code === category);
            if (!profile || typeof profile.passThresholdPercent !== 'number') return;
            const passed = percentage >= profile.passThresholdPercent;
            const blueprintVersion = profile.blueprint?.version || '';
            if (unmountedRef.current) return;
            setThreshold({
                verdict: passed ? 'PASS' : 'BELOW THRESHOLD',
                detail:
                    ` ${profile.code} pass threshold ${profile.passThresholdPercent}%` +
                    `${blueprintVersion ? ` (curriculum ${blueprintVersion})` : ''} — your score ${percentage.toFixed(1)}%.` +
                    ' This is a practice indicator, not an official result.'
            });
        } catch (error) {
            console.error('Error rendering pass threshold info:', error);
        }
    }

    async function fetchExamResults(examIdArg?: string | null) {
        let examId = examIdArg ?? null;
        if (!examId) {
            examId = getQueryParam('id');
            if (!examId) {
                showError('No exam ID provided. Please return to the dashboard.');
                return;
            }
        }
        examIdRef.current = examId;
        setState({ kind: 'loading', message: 'Loading exam results...' });
        setReEvaluating(false);
        try {
            const response = await fetch(`${API_BASE}/exams/${examId}/result`);
            if (!response.ok) {
                if (response.status === 404) {
                    await checkResultsStatus(examId);
                    return;
                }
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            const data = (await response.json()) as { data?: ExamResults };
            if (data && data.data) {
                setState({ kind: 'ready', results: data.data });
                void renderPassThreshold(data.data, examId);
            } else {
                throw new Error('Invalid response format');
            }
        } catch (error) {
            console.error('Error loading exam results:', error);
            showError((error as Error).message || 'Failed to load exam results');
        }
    }

    const startedRef = useRef(false);
    useEffect(() => {
        if (startedRef.current) return;
        startedRef.current = true;
        void fetchExamResults();
        return () => {
            unmountedRef.current = true;
            stopPolling();
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    function handleReEvaluate() {
        const examId = examIdRef.current;
        if (!examId) {
            showError('No exam ID available for re-evaluation.');
            return;
        }
        setReEvaluating(true);
        setState({ kind: 'loading', message: 'Re-evaluation in progress...' });
        void (async () => {
            try {
                const response = await fetch(`${API_BASE}/exams/${examId}/evaluate`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' }
                });
                if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
                await response.json();
                startPolling(examId);
            } catch (error) {
                console.error('Error starting re-evaluation:', error);
                setReEvaluating(false);
                showError('Failed to start re-evaluation: ' + (error as Error).message);
            }
        })();
    }

    function handleConfirmTerminate() {
        const examId = examIdRef.current;
        if (!examId) return;
        setTerminating(true);
        void (async () => {
            try {
                const response = await fetch(`${API_BASE}/exams/${examId}/terminate`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' }
                });
                if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
                await response.json();
                navigate('/');
            } catch (error) {
                console.error('Error terminating session:', error);
                setTerminating(false);
                setTerminateOpen(false);
                showError('Failed to terminate session: ' + (error as Error).message);
            }
        })();
    }

    return (
        <div className="mx-auto w-full max-w-[1000px] px-4 pb-16 pt-8">
            <div className="mb-6 flex flex-wrap gap-2">
                <Button id="dashboardBtn" variant="secondary" onClick={() => navigate('/')}>
                    <Home aria-hidden size={15} className="mr-1.5" /> Dashboard
                </Button>
                <Button
                    id="currentExamBtn"
                    variant="outline"
                    onClick={() => {
                        if (examIdRef.current) openInNewTab(`/exam.html?id=${examIdRef.current}`);
                        else showError('No exam ID available for redirection.');
                    }}
                >
                    <ListTodo aria-hidden size={15} className="mr-1.5" /> Current Exam
                </Button>
                <Button
                    id="viewAnswersBtn"
                    variant="outline"
                    onClick={() => {
                        if (examIdRef.current) openInNewTab(`/answers.html?id=${examIdRef.current}`);
                        else showError('No exam ID available for viewing answers.');
                    }}
                >
                    <CheckSquare aria-hidden size={15} className="mr-1.5" /> View Answers
                </Button>
                <Button id="reEvaluateBtn" disabled={reEvaluating} onClick={handleReEvaluate}>
                    <RefreshCw aria-hidden size={15} className="mr-1.5" />
                    {reEvaluating ? 'Evaluating...' : 'Re-evaluate Exam'}
                </Button>
                <Button id="terminateBtn" variant="danger" onClick={() => setTerminateOpen(true)}>
                    <Power aria-hidden size={15} className="mr-1.5" /> Terminate Session
                </Button>
            </div>

            {state.kind === 'loading' ? (
                <div id="pageLoader" role="status" className="py-20 text-center">
                    <div className="mx-auto mb-4 h-8 w-8 animate-spin rounded-full border-2 border-line-strong border-t-primary" />
                    <p id="loaderMessage" className="text-ink-secondary">
                        {state.message}
                    </p>
                </div>
            ) : null}

            {state.kind === 'error' ? (
                <div id="errorMessage" role="alert" className="py-16 text-center">
                    <p id="errorText" className="mb-4 text-bad">
                        {state.message}
                    </p>
                    <Button id="retryButton" variant="secondary" onClick={() => void fetchExamResults()}>
                        Retry
                    </Button>
                </div>
            ) : null}

            {state.kind === 'ready' ? (
                <div id="resultsContent">
                    <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
                        <h1 className="text-2xl font-bold tracking-tight">Exam Results</h1>
                        <div className="text-right text-sm text-ink-muted">
                            <p id="examId">Exam ID: {state.results.examId}</p>
                            <p id="completedAt">Completed: {formatDate(state.results.completedAt)}</p>
                        </div>
                    </div>

                    <Card className="mb-4">
                        <CardContent className="flex flex-wrap items-center justify-between gap-4">
                            <div>
                                <h2 className="mb-1 text-sm font-semibold uppercase tracking-wide text-ink-muted">
                                    Solved subtasks:
                                </h2>
                                <div className="text-3xl font-bold">
                                    <span id="totalScore">{state.results.totalScore}</span>{' '}
                                    <span className="text-ink-muted">/</span>{' '}
                                    <span id="totalPossibleScore">{state.results.totalPossibleScore}</span>
                                </div>
                            </div>
                            <div
                                id="rankBadge"
                                className={cn(
                                    'rounded-full px-4 py-2 text-sm font-bold',
                                    state.results.rank === 'high' && 'bg-good/15 text-good',
                                    state.results.rank === 'medium' && 'bg-warn/15 text-warn',
                                    state.results.rank !== 'high' &&
                                        state.results.rank !== 'medium' &&
                                        'bg-bad/15 text-bad'
                                )}
                            >
                                <span id="rankText">
                                    {state.results.rank === 'high'
                                        ? 'High Score'
                                        : state.results.rank === 'medium'
                                          ? 'Medium Score'
                                          : 'Low Score'}
                                </span>
                            </div>
                        </CardContent>
                    </Card>

                    {threshold ? (
                        <div
                            id="passThresholdInfo"
                            role="status"
                            className="mb-4 rounded-ckx border border-line bg-surface-raised p-3 text-sm"
                        >
                            <span
                                className={cn(
                                    'mr-1 rounded-full px-2.5 py-0.5 text-xs font-bold',
                                    threshold.verdict === 'PASS'
                                        ? 'bg-good/15 text-good'
                                        : 'bg-bad/15 text-bad'
                                )}
                            >
                                {threshold.verdict}
                            </span>
                            <span className="text-ink-secondary">{threshold.detail}</span>
                        </div>
                    ) : null}

                    <div id="questionsContainer" className="flex flex-col gap-4">
                        {state.results.evaluationResults && state.results.evaluationResults.length ? (
                            sortById(state.results.evaluationResults).map((question) => (
                                <QuestionCard
                                    key={question.id}
                                    question={question}
                                    examId={examIdRef.current || ''}
                                />
                            ))
                        ) : (
                            <p>No evaluation results available</p>
                        )}
                    </div>
                </div>
            ) : null}

            {terminateOpen ? (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
                    <div
                        id="terminateModal"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="terminateModalTitle"
                        className="w-full max-w-[480px] rounded-ckx-lg border border-line-strong bg-surface p-6 text-ink shadow-ckx-lg"
                    >
                        <div className="mb-4 flex items-center justify-between">
                            <h2 id="terminateModalTitle" className="text-lg font-semibold">
                                Terminate Session
                            </h2>
                            <button
                                id="closeModalBtn"
                                type="button"
                                aria-label="Close"
                                className="rounded-ckx-sm p-1 text-ink-muted hover:bg-surface-soft hover:text-ink"
                                onClick={() => setTerminateOpen(false)}
                            >
                                ×
                            </button>
                        </div>
                        <div className="text-sm text-ink-secondary">
                            <p>Are you sure you want to terminate this exam session?</p>
                            <p className="mt-2">
                                This will <strong>clear all your progress</strong> and your{' '}
                                <strong>environment will be cleaned up</strong> immediately.
                            </p>
                            <p className="mt-2 font-semibold text-bad">This action cannot be undone.</p>
                        </div>
                        <div className="mt-5 flex justify-end gap-2">
                            <Button
                                id="cancelTerminateBtn"
                                variant="secondary"
                                onClick={() => setTerminateOpen(false)}
                            >
                                Cancel
                            </Button>
                            <Button
                                id="confirmTerminateBtn"
                                variant="danger"
                                disabled={terminating}
                                onClick={handleConfirmTerminate}
                            >
                                <Power aria-hidden size={15} className="mr-1.5" />
                                {terminating ? 'Terminating...' : 'Terminate Session'}
                            </Button>
                        </div>
                    </div>
                </div>
            ) : null}

            <footer className="mt-12 border-t border-line py-5 text-center text-sm text-ink-muted">
                © {new Date().getFullYear()} CK-X Simulator.
            </footer>
        </div>
    );
}

// One evaluated question: sorted verification steps, per-question score,
// and the log-mistake control when any step failed.
function QuestionCard({ question, examId }: { question: EvaluationQuestion; examId: string }) {
    const sortedVerifications = sortById(question.verificationResults);
    const questionScore = sortedVerifications.reduce((total, v) => total + v.score, 0);
    const questionPossibleScore = sortedVerifications.reduce((total, v) => total + v.weightage, 0);
    const failedSteps = sortedVerifications.filter((v) => !v.validAnswer);

    return (
        <Card className="question-card">
            <CardContent>
                <div className="mb-3 flex items-center justify-between">
                    <h3 className="question-title text-base font-semibold">Question {question.id}</h3>
                    <div className="text-sm text-ink-muted">
                        {questionScore} of {questionPossibleScore}
                    </div>
                </div>
                <ul className="flex flex-col gap-1.5">
                    {sortedVerifications.map((verification) => (
                        <li
                            key={verification.id}
                            className="flex items-center justify-between gap-3 rounded-ckx-sm border border-line bg-surface-soft px-3 py-2 text-sm"
                        >
                            <span>{verification.description || ''}</span>
                            {verification.validAnswer ? (
                                <CheckCircle2 aria-label="Passed" className="shrink-0 text-good" size={16} />
                            ) : (
                                <XCircle aria-label="Failed" className="shrink-0 text-bad" size={16} />
                            )}
                        </li>
                    ))}
                </ul>
                {failedSteps.length > 0 ? <LogMistakeControl question={question} failedSteps={failedSteps} examId={examId} /> : null}
            </CardContent>
        </Card>
    );
}

function LogMistakeControl({
    question,
    failedSteps,
    examId
}: {
    question: EvaluationQuestion;
    failedSteps: VerificationResult[];
    examId: string;
}) {
    const [status, setStatus] = useState('');
    const [busy, setBusy] = useState(false);

    async function resolveAttemptContext(): Promise<AttemptRecord | null> {
        try {
            const response = await fetch(`${API_BASE}/exams/attempts`);
            if (!response.ok) return null;
            const payload = (await response.json()) as {
                data?: { attempts?: AttemptRecord[] };
            };
            const attempts = payload?.data?.attempts || [];
            return attempts.find((attempt) => attempt.examSessionId === examId) || null;
        } catch {
            return null;
        }
    }

    async function handleLogMistake() {
        setBusy(true);
        setStatus('Saving…');
        try {
            const attemptRecord = await resolveAttemptContext();
            const payload = {
                summary: `Question ${question.id}: ${failedSteps[0]!.description}`,
                category: 'other',
                source: {
                    attemptId: attemptRecord ? attemptRecord.attemptId : examId,
                    questionId: String(question.id),
                    labId: attemptRecord ? attemptRecord.labId : '',
                    labName: attemptRecord ? attemptRecord.labName : '',
                    certificationCode: attemptRecord ? (attemptRecord.certificationCode || null) : null,
                    concepts: question.concepts || [],
                    failedValidationSteps: failedSteps.map((step) => ({
                        id: String(step.id),
                        description: step.description
                    }))
                }
            };
            const response = await fetch(`${API_BASE}/mistakes`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = (await response.json()) as {
                message?: string;
                data?: { duplicate?: boolean };
            };
            if (!response.ok) throw new Error(data.message || 'Request rejected');
            setStatus(
                data.data?.duplicate
                    ? 'Already in the mistake log.'
                    : 'Logged. Categorize it on the Mistakes page.'
            );
        } catch (error) {
            console.error('Failed to log mistake:', error);
            setStatus('Failed to log mistake.');
            setBusy(false);
        }
    }

    return (
        <div className="mt-3 flex flex-wrap items-center gap-2">
            <Button size="sm" variant="outline" disabled={busy} onClick={() => void handleLogMistake()}>
                Log mistake for review
            </Button>
            <span role="status" className="text-xs text-ink-muted">
                {status}
            </span>
        </div>
    );
}
