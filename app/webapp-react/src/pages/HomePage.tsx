import { useEffect, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
    Award,
    ChartLine,
    Clock,
    ListChecks,
    Lock,
    Terminal as TerminalIcon,
    ClipboardCheck,
    MonitorCheck,
    Layers,
    Timer,
    ListTree,
    Boxes,
    UserCheck
} from 'lucide-react';
import { AppShell } from '@/components/shell/AppShell';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Chip } from '@/components/ui/chip';
import { API_BASE, postJson } from '@/lib/api';
import { navigate } from '@/lib/navigation';
import { usePageTitle } from '@/lib/use-page-title';

// React port of index.html + js/index.js. Same endpoints (including the
// /assements/ typo), same localStorage keys and sweep, same modal flow,
// same 1s lab-prep polling with capped progress. Legacy ids/classes kept
// as hooks for the Playwright baseline.

interface Lab {
    id: string;
    name: string;
    category?: string;
    description?: string;
    difficulty?: string;
    examDurationInMinutes?: number | string;
    estimatedTime?: number | string;
}

interface CertProfile {
    code: string;
    displayName?: string;
}

interface CurrentExam {
    id: string;
    status: string;
    info?: { name?: string; category?: string };
}

interface FailedConcept {
    name: string;
    failedStepCount?: number;
}

interface FailedQuestion {
    questionTitle: string;
    failedValidationSteps: { description: string }[];
}

interface Attempt {
    attemptId?: string;
    examSessionId?: string;
    labId: string;
    labName: string;
    category: string;
    completedAt: string;
    percentageScore: number;
    totalScore: number;
    totalPossibleScore: number;
    scoreLevel?: string;
    failedConcepts?: FailedConcept[];
    failedQuestions?: FailedQuestion[];
}

interface AttemptFilters {
    categories?: string[];
    labs?: { labId: string; labName: string }[];
    failedConcepts?: string[];
}

interface AttemptsPayload {
    data?: { attempts?: Attempt[]; filters?: AttemptFilters };
}

const CATEGORY_FALLBACK_LABELS: Record<string, string> = {
    CKAD: 'CKAD - Certified Kubernetes Application Developer',
    CKA: 'CKA - Certified Kubernetes Administrator',
    CKS: 'CKS - Certified Kubernetes Security Specialist',
    KCNA: 'KCNA - Kubernetes and Cloud Native Associate',
    KCSA: 'KCSA - Kubernetes and Cloud Native Security Associate',
    Other: 'Other'
};

// Remove per-exam localStorage state (pause/progress) that does not belong
// to the active exam session. Pass null to sweep all such keys.
function clearStaleExamStateKeys(activeExamId: string | null) {
    const prefixes = ['ckx-exam-paused:', 'ckx-exam-progress:'];
    const staleKeys: string[] = [];
    for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        const prefix = prefixes.find((p) => key && key.startsWith(p));
        if (!prefix || !key) continue;
        const keyExamId = key.slice(prefix.length);
        if (!activeExamId || keyExamId !== activeExamId) {
            staleKeys.push(key);
        }
    }
    staleKeys.forEach((key) => localStorage.removeItem(key));
}

function formatAttemptDate(dateString?: string) {
    if (!dateString) return 'Unknown date';
    return new Date(dateString).toLocaleString(undefined, {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function countNames(names: (string | undefined)[]) {
    const counts = new Map<string, number>();
    names.forEach((name) => {
        if (name) counts.set(name, (counts.get(name) || 0) + 1);
    });
    return Array.from(counts.entries())
        .map(([name, count]) => ({ name, count }))
        .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
}

function getLatestFailedAttempt(attempts: Attempt[]) {
    return (
        attempts
            .filter((attempt) => (attempt.failedQuestions || []).length > 0)
            .sort(
                (a, b) => new Date(b.completedAt).getTime() - new Date(a.completedAt).getTime()
            )[0] || null
    );
}

function getTrendText(attempts: Attempt[]) {
    const byLab = new Map<string, Attempt[]>();
    attempts.forEach((attempt) => {
        const key = attempt.labId || attempt.labName;
        const entries = byLab.get(key) || [];
        entries.push(attempt);
        byLab.set(key, entries);
    });

    const trends = Array.from(byLab.values())
        .filter((entries) => entries.length > 1)
        .map((entries) => {
            const sorted = entries.sort(
                (a, b) => new Date(a.completedAt).getTime() - new Date(b.completedAt).getTime()
            );
            const previous = sorted[sorted.length - 2]!;
            const latest = sorted[sorted.length - 1]!;
            return { labName: latest.labName, delta: latest.percentageScore - previous.percentageScore };
        })
        .sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));

    if (trends.length === 0) return 'Need 2 attempts on the same lab';
    const trend = trends[0]!;
    const sign = trend.delta > 0 ? '+' : '';
    return `${sign}${trend.delta}% on ${trend.labName}`;
}

const HERO_STATS = [
    { icon: Award, value: '5', label: 'Exam Tracks' },
    { icon: ListChecks, value: '16+', label: 'Questions per Mock' },
    { icon: Clock, value: '120', label: 'Minute Timed Mocks' },
    { icon: TerminalIcon, value: '1:1', label: 'Real Exam Terminal' },
    { icon: ChartLine, value: '100', label: 'Marks per Exam' },
    { icon: Lock, value: '100%', label: 'Local & Private' }
];

const FEATURES = [
    {
        icon: MonitorCheck,
        title: 'Real Exam Environment',
        text: 'Practice in a simulated environment that closely resembles the actual Kubernetes certification exam interface.',
        tags: ['Terminal', 'Split View']
    },
    {
        icon: Layers,
        title: 'Multiple Certification Support',
        text: 'Practice for CKA, CKAD, and other Kubernetes certification exams with tailored scenarios for each exam type.',
        tags: ['CKA', 'CKAD', 'CKS']
    },
    {
        icon: Timer,
        title: 'Timed Practice',
        text: 'Prepare for the time pressure of the actual exams with our realistic timer functionality.',
        tags: ['Countdown', 'Exam Pace']
    },
    {
        icon: ListTree,
        title: 'Detailed Scoring & Solutions',
        text: 'Review your performance with comprehensive exam scores and access detailed solutions to enhance your learning.',
        tags: ['Weak Areas', 'Solutions']
    },
    {
        icon: Boxes,
        title: 'Realistic Kubernetes Cluster',
        text: 'Practice on actual Kubernetes infrastructure that mimics the exam environment with pre-configured namespaces and resources.',
        tags: ['Live Cluster', 'Namespaces']
    },
    {
        icon: UserCheck,
        title: 'User-Focused Experience',
        text: 'Enjoy a streamlined and accessible interface designed to help you focus on mastering Kubernetes concepts without distractions.',
        tags: ['Accessible', 'Focused']
    }
];

interface OverlayState {
    visible: boolean;
    progress: number;
    message: string;
    examInfo: string;
}

const selectClass =
    'w-full rounded-ckx-sm border border-line-strong bg-surface-soft p-2 text-sm text-ink';

export function HomePage() {
    usePageTitle('CK-X — Local Kubernetes Certification Simulator');

    // ---------- data ----------
    const labsQuery = useQuery({
        queryKey: ['labs'],
        queryFn: async () => {
            const response = await fetch(`${API_BASE}/assements/`);
            if (!response.ok) throw new Error('Failed to fetch labs. Status: ' + response.status);
            return (await response.json()) as Lab[];
        }
    });
    const labs = labsQuery.data ?? [];

    const certsQuery = useQuery({
        queryKey: ['certifications'],
        queryFn: async () => {
            const response = await fetch(`${API_BASE}/certifications`);
            if (!response.ok)
                throw new Error('Failed to fetch certifications. Status: ' + response.status);
            return (await response.json()) as { certifications?: CertProfile[] };
        }
    });
    const certProfiles = new Map<string, CertProfile>();
    (certsQuery.data?.certifications || []).forEach((profile) => {
        certProfiles.set(profile.code, profile);
    });

    function getCategoryLabel(category: string) {
        const profile = certProfiles.get(category);
        if (profile?.displayName) return `${profile.code} - ${profile.displayName}`;
        return CATEGORY_FALLBACK_LABELS[category] || category;
    }

    const attemptsQuery = useQuery({
        queryKey: ['attempts'],
        queryFn: async () => {
            const response = await fetch(`${API_BASE}/exams/attempts`);
            if (!response.ok)
                throw new Error('Failed to load previous attempts. Status: ' + response.status);
            return (await response.json()) as AttemptsPayload;
        }
    });
    const attemptHistory = attemptsQuery.data?.data?.attempts || [];
    const attemptFilters = attemptsQuery.data?.data?.filters || {};

    // ---------- overlay + polling ----------
    const [overlay, setOverlay] = useState<OverlayState>({
        visible: false,
        progress: 0,
        message: 'Initializing environment...',
        examInfo: ''
    });
    const pollAbortRef = useRef(false);

    function pollExamStatus(examId: string): Promise<void> {
        const startTime = Date.now();
        const pollInterval = 1000;
        return new Promise((resolve) => {
            const poll = async () => {
                if (pollAbortRef.current) return;
                try {
                    const response = await fetch(`${API_BASE}/exams/${examId}/status`);
                    const data = (await response.json()) as {
                        status?: string;
                        message?: string;
                        warmUpTimeInSeconds?: number;
                    };
                    const warmUpTimeInSeconds = data.warmUpTimeInSeconds || 30;
                    if (data.status === 'READY') {
                        setOverlay((current) => ({
                            ...current,
                            progress: 100,
                            message: 'Lab environment is ready! Redirecting...'
                        }));
                        setTimeout(() => resolve(), 1000);
                        return;
                    }
                    const elapsedTime = (Date.now() - startTime) / 1000;
                    const progress = Math.min((elapsedTime / warmUpTimeInSeconds) * 100, 95);
                    setOverlay((current) => ({
                        ...current,
                        progress,
                        message: data.message || 'Preparing lab environment...'
                    }));
                    setTimeout(poll, pollInterval);
                } catch (error) {
                    console.error('Error polling exam status:', error);
                    setOverlay((current) => ({
                        ...current,
                        message: `Error: ${(error as Error).message}. Retrying...`
                    }));
                    setTimeout(poll, pollInterval);
                }
            };
            void poll();
        });
    }

    useEffect(() => {
        // StrictMode mounts, cleans up, then mounts again — reset the abort
        // flag on setup so the second mount's polling isn't dead on arrival.
        pollAbortRef.current = false;
        return () => {
            pollAbortRef.current = true;
        };
    }, []);

    // ---------- current session check on load ----------
    const [viewResultVisible, setViewResultVisible] = useState(false);
    const checkedRef = useRef(false);
    useEffect(() => {
        if (checkedRef.current) return;
        checkedRef.current = true;
        void (async () => {
            try {
                const response = await fetch(`${API_BASE}/exams/current`);
                if (!response.ok) {
                    clearStaleExamStateKeys(null);
                    return;
                }
                const data = (await response.json()) as CurrentExam;
                if (!data || !data.id) {
                    clearStaleExamStateKeys(null);
                    return;
                }
                clearStaleExamStateKeys(data.id);
                localStorage.setItem('currentExamData', JSON.stringify(data));
                if (data.status === 'EVALUATING' || data.status === 'EVALUATED') {
                    setViewResultVisible(true);
                }
                if (data.status === 'PREPARING') {
                    setOverlay({
                        visible: true,
                        progress: 0,
                        message: 'Preparing lab environment...',
                        examInfo: data.info?.name || 'Unknown Exam'
                    });
                    await pollExamStatus(data.id);
                    navigate(`/exam.html?id=${data.id}`);
                }
            } catch (error) {
                console.error('Error checking current exam status:', error);
            }
        })();
    }, []);

    // ---------- exam selection modal ----------
    const [selectionOpen, setSelectionOpen] = useState(false);
    const [warningExam, setWarningExam] = useState<CurrentExam | null>(null);
    const [terminating, setTerminating] = useState(false);
    const [category, setCategory] = useState('');
    const [selectedLabId, setSelectedLabId] = useState('');
    const [starting, setStarting] = useState(false);

    const categories = [...new Set(labs.map((lab) => lab.category).filter(Boolean))] as string[];
    const filteredLabs = labs.filter((lab) => lab.category === category);
    const selectedLab = labs.find((lab) => lab.id === selectedLabId) || null;

    function openSelectionModal() {
        // Legacy default: CKAD when available, else the first category
        const initialCategory = categories.includes('CKAD') ? 'CKAD' : categories[0] || '';
        const initialLabs = labs.filter((lab) => lab.category === initialCategory);
        setCategory(initialCategory);
        setSelectedLabId(initialLabs[0]?.id || '');
        setSelectionOpen(true);
    }

    async function ensureLabsAndOpen() {
        if (labs.length > 0) {
            openSelectionModal();
            return;
        }
        const result = await labsQuery.refetch();
        if (result.data && result.data.length > 0) {
            const initialCategory = [...new Set(result.data.map((lab) => lab.category).filter(Boolean))] as string[];
            const first = initialCategory.includes('CKAD') ? 'CKAD' : initialCategory[0] || '';
            setCategory(first);
            setSelectedLabId(result.data.filter((lab) => lab.category === first)[0]?.id || '');
            setSelectionOpen(true);
        } else {
            alert('Failed to load labs. Please try again later.');
        }
    }

    async function handleStartExamClick(event: React.MouseEvent) {
        event.preventDefault();
        try {
            const response = await fetch(`${API_BASE}/exams/current`);
            if (response.status === 404) {
                await ensureLabsAndOpen();
                return;
            }
            if (!response.ok) {
                console.error('Error checking current exam status:', response.status);
                return;
            }
            const data = (await response.json()) as CurrentExam;
            if (data && data.id) {
                setWarningExam(data);
            }
        } catch (error) {
            console.error('Error checking for active exam:', error);
            await ensureLabsAndOpen();
        }
    }

    async function handleTerminateAndProceed() {
        if (!warningExam) return;
        setTerminating(true);
        setOverlay((current) => ({
            ...current,
            visible: true,
            message: 'Terminating active session...'
        }));
        try {
            const response = await fetch(`${API_BASE}/exams/${warningExam.id}/terminate`, {
                method: 'POST'
            });
            if (!response.ok) {
                throw new Error('Failed to terminate exam. Status: ' + response.status);
            }
            await response.json();
            setWarningExam(null);
            localStorage.removeItem('currentExamData');
            localStorage.removeItem('currentExamId');
            setOverlay((current) => ({ ...current, visible: false }));
            await ensureLabsAndOpen();
        } catch (error) {
            console.error('Error terminating exam:', error);
            setOverlay((current) => ({ ...current, visible: false }));
            alert('Failed to terminate the active exam. Please try again later.');
        } finally {
            setTerminating(false);
        }
    }

    async function handleStartSelectedExam() {
        if (!selectedLab) return;
        setStarting(true);
        setSelectionOpen(false);
        setOverlay({
            visible: true,
            progress: 0,
            message: 'Starting lab environment...',
            examInfo: `Lab: ${selectedLab.name} | Difficulty: ${selectedLab.difficulty || 'Medium'}`
        });
        let userAgent = '';
        try {
            userAgent = navigator.userAgent;
        } catch (error) {
            console.error('Error getting user agent:', error);
        }
        try {
            const response = await fetch(`${API_BASE}/exams/`, postJson({ ...selectedLab, userAgent }));
            if (!response.ok) {
                throw new Error('Failed to start lab. Status: ' + response.status);
            }
            const data = (await response.json()) as { id: string; warmUpTimeInSeconds?: number };
            localStorage.setItem('currentExamId', data.id);
            const warmUpTime = data.warmUpTimeInSeconds || 30;
            setOverlay((current) => ({
                ...current,
                message: `Preparing your lab environment (${warmUpTime}s estimated)`
            }));
            await pollExamStatus(data.id);
            navigate(`/exam.html?id=${data.id}`);
        } catch (error) {
            console.error('Error starting lab:', error);
            setOverlay((current) => ({ ...current, visible: false }));
            alert('Failed to start the lab. Please try again later.');
        } finally {
            setStarting(false);
        }
    }

    function handleViewResults(event: React.MouseEvent) {
        event.preventDefault();
        const currentExamDataStr = localStorage.getItem('currentExamData');
        if (currentExamDataStr) {
            try {
                const currentExamData = JSON.parse(currentExamDataStr) as CurrentExam;
                if (currentExamData.status === 'EVALUATED' || currentExamData.status === 'EVALUATING') {
                    navigate(`/results?id=${currentExamData.id}`);
                    return;
                }
                alert('Exam results are not available yet. The exam must be evaluated first.');
                return;
            } catch (error) {
                console.error('Error parsing current exam data:', error);
            }
        }
        alert('No active exam found. Please start an exam first.');
    }

    // ---------- attempts filters ----------
    const [attemptCategory, setAttemptCategory] = useState('');
    const [attemptLab, setAttemptLab] = useState('');
    const [attemptConcept, setAttemptConcept] = useState('');
    const [attemptFrom, setAttemptFrom] = useState('');
    const [attemptTo, setAttemptTo] = useState('');

    const filteredAttempts = attemptHistory.filter((attempt) => {
        const completedAt = new Date(attempt.completedAt);
        if (attemptCategory && attempt.category !== attemptCategory) return false;
        if (attemptLab && attempt.labId !== attemptLab) return false;
        if (attemptConcept) {
            const hasConcept = (attempt.failedConcepts || []).some(
                (concept) => concept.name === attemptConcept
            );
            if (!hasConcept) return false;
        }
        if (attemptFrom && completedAt < new Date(`${attemptFrom}T00:00:00`)) return false;
        if (attemptTo && completedAt > new Date(`${attemptTo}T23:59:59`)) return false;
        return true;
    });

    const failedConceptCounts = countNames(
        filteredAttempts.flatMap((attempt) =>
            (attempt.failedConcepts || []).map((concept) => concept.name)
        )
    );
    const latestFailedAttempt = getLatestFailedAttempt(filteredAttempts);
    const weakConcepts = failedConceptCounts.slice(0, 8);
    const weakQuestions = countNames(
        filteredAttempts.flatMap((attempt) =>
            (attempt.failedQuestions || []).map(
                (question) => `${attempt.labName} - ${question.questionTitle}`
            )
        )
    ).slice(0, 5);

    const attemptsState = attemptsQuery.isPending
        ? 'loading'
        : attemptsQuery.isError
          ? 'error'
          : attemptHistory.length === 0
            ? 'empty'
            : 'ready';

    // ---------- render ----------
    return (
        <AppShell
            activeHref="/"
            navExtra={
                viewResultVisible ? (
                    <a
                        href="#"
                        id="viewPastResultsBtn"
                        onClick={handleViewResults}
                        className="flex items-center gap-1.5 rounded-ckx-sm px-3 py-1.5 text-sm font-medium text-ink-secondary hover:bg-surface-soft hover:text-ink"
                    >
                        <ClipboardCheck aria-hidden size={16} />
                        View Result
                    </a>
                ) : null
            }
        >
            {/* Hero */}
            <section className="command-panel pt-6 text-center">
                <div className="mx-auto flex max-w-[860px] flex-col items-center gap-5">
                    <Chip tone="primary">Local-first · Runs on your machine</Chip>
                    <h1 className="command-title text-4xl font-bold leading-tight tracking-tight md:text-5xl">
                        Local Kubernetes <span className="ckx-gradient-text">Certification Simulator</span>
                    </h1>
                    <p className="max-w-[640px] text-ink-secondary">
                        Practice CKA, CKAD, CKS, KCNA and KCSA exams in a realistic, terminal-driven
                        environment that mirrors the real thing — entirely on your own machine.
                    </p>
                    <div
                        aria-hidden="true"
                        className="rounded-ckx border border-line-strong px-4 py-2 font-mono text-sm text-ink-secondary"
                        style={{ backgroundColor: 'var(--ckx-cmd-bg, #12121a)', color: '#d3d7e8' }}
                    >
                        <span className="text-good">$</span> docker compose up -d
                    </div>
                    <div className="flex flex-wrap items-center justify-center gap-3">
                        <Button size="lg" id="startExamBtn" onClick={handleStartExamClick}>
                            Start Exam
                        </Button>
                        <Button size="lg" variant="secondary" onClick={() => navigate('/analytics.html')}>
                            View Analytics
                        </Button>
                    </div>
                    <div className="mt-2 grid w-full grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
                        {HERO_STATS.map((stat) => (
                            <div
                                key={stat.label}
                                className="hero-stat rounded-ckx border border-line bg-surface-raised p-3 text-center"
                            >
                                <stat.icon aria-hidden className="mx-auto mb-1 text-primary" size={18} />
                                <div className="text-lg font-bold">{stat.value}</div>
                                <div className="text-xs text-ink-muted">{stat.label}</div>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Previous attempts */}
            <section id="previousAttempts" className="mt-14">
                <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
                    <div>
                        <h2 className="text-2xl font-bold tracking-tight">Previous Attempts</h2>
                        <p className="mt-1 text-sm text-ink-secondary">
                            Review past scores, failed questions, and weak areas across your local
                            practice history.
                        </p>
                    </div>
                    <Button id="refreshAttemptsBtn" onClick={() => void attemptsQuery.refetch()}>
                        Refresh Results
                    </Button>
                </div>

                {attemptsState === 'loading' ? (
                    <div id="attemptsLoading" className="text-sm text-ink-muted" role="status">
                        Loading previous attempts...
                    </div>
                ) : null}
                {attemptsState === 'error' ? (
                    <div id="attemptsError" className="text-sm text-bad" role="alert">
                        {(attemptsQuery.error as Error | null)?.message ||
                            'Previous attempts are unavailable.'}
                    </div>
                ) : null}
                {attemptsState === 'empty' ? (
                    <div id="attemptsEmpty" className="text-sm text-ink-muted">
                        No previous attempts yet. Complete an exam to build your weak-area history.
                    </div>
                ) : null}

                {attemptsState === 'ready' ? (
                    <div id="attemptsContent">
                        <div
                            id="attemptSummaryGrid"
                            className="mb-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4"
                        >
                            {[
                                {
                                    label: 'Attempts',
                                    value: String(filteredAttempts.length),
                                    note: 'Matching current filters'
                                },
                                {
                                    label: 'Top Weak Area',
                                    value: failedConceptCounts[0]?.name || 'None yet',
                                    note: `${failedConceptCounts[0]?.count || 0} failed appearances`
                                },
                                {
                                    label: 'Latest Failed Attempt',
                                    value: latestFailedAttempt
                                        ? `${latestFailedAttempt.percentageScore}%`
                                        : 'None',
                                    note: latestFailedAttempt?.labName || 'No failed steps found'
                                },
                                {
                                    label: 'Improvement Trend',
                                    value: getTrendText(filteredAttempts),
                                    note: 'Compared by lab'
                                }
                            ].map((card) => (
                                <Card key={card.label}>
                                    <CardContent className="p-4">
                                        <div className="text-xs uppercase tracking-wide text-ink-muted">
                                            {card.label}
                                        </div>
                                        <div className="mt-1 truncate text-lg font-bold" title={card.value}>
                                            {card.value}
                                        </div>
                                        <div className="mt-0.5 text-xs text-ink-muted">{card.note}</div>
                                    </CardContent>
                                </Card>
                            ))}
                        </div>

                        <div className="mb-4 grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-6">
                            <select
                                className={selectClass}
                                id="attemptCategoryFilter"
                                aria-label="Filter by category"
                                value={attemptCategory}
                                onChange={(event) => setAttemptCategory(event.target.value)}
                            >
                                <option value="">All categories</option>
                                {(attemptFilters.categories || []).map((value) => (
                                    <option key={value} value={value}>
                                        {getCategoryLabel(value)}
                                    </option>
                                ))}
                            </select>
                            <select
                                className={selectClass}
                                id="attemptLabFilter"
                                aria-label="Filter by lab"
                                value={attemptLab}
                                onChange={(event) => setAttemptLab(event.target.value)}
                            >
                                <option value="">All labs</option>
                                {(attemptFilters.labs || []).map((lab) => (
                                    <option key={lab.labId} value={lab.labId}>
                                        {lab.labName}
                                    </option>
                                ))}
                            </select>
                            <select
                                className={selectClass}
                                id="attemptConceptFilter"
                                aria-label="Filter by weak area"
                                value={attemptConcept}
                                onChange={(event) => setAttemptConcept(event.target.value)}
                            >
                                <option value="">All weak areas</option>
                                {(attemptFilters.failedConcepts || []).map((value) => (
                                    <option key={value} value={value}>
                                        {value}
                                    </option>
                                ))}
                            </select>
                            <input
                                className={selectClass}
                                type="date"
                                id="attemptFromFilter"
                                aria-label="Attempts from date"
                                value={attemptFrom}
                                onChange={(event) => setAttemptFrom(event.target.value)}
                            />
                            <input
                                className={selectClass}
                                type="date"
                                id="attemptToFilter"
                                aria-label="Attempts to date"
                                value={attemptTo}
                                onChange={(event) => setAttemptTo(event.target.value)}
                            />
                            <Button
                                variant="secondary"
                                id="clearAttemptFiltersBtn"
                                onClick={() => {
                                    setAttemptCategory('');
                                    setAttemptLab('');
                                    setAttemptConcept('');
                                    setAttemptFrom('');
                                    setAttemptTo('');
                                }}
                            >
                                Clear
                            </Button>
                        </div>

                        <div className="grid grid-cols-1 gap-4 xl:grid-cols-[2fr_1fr]">
                            <Card>
                                <CardContent>
                                    <h3 className="mb-3 text-lg font-semibold">Review Results</h3>
                                    <div className="overflow-x-auto">
                                        <table className="w-full text-left text-sm">
                                            <thead>
                                                <tr className="border-b border-line text-xs uppercase tracking-wide text-ink-muted">
                                                    <th className="pb-2 pr-3">Attempt</th>
                                                    <th className="pb-2 pr-3">Score</th>
                                                    <th className="pb-2 pr-3">Weak Areas</th>
                                                    <th className="pb-2">Failed Questions</th>
                                                </tr>
                                            </thead>
                                            <tbody id="attemptsTableBody">
                                                {filteredAttempts.length === 0 ? (
                                                    <tr>
                                                        <td colSpan={4} className="py-3 text-ink-muted">
                                                            No attempts match the selected filters.
                                                        </td>
                                                    </tr>
                                                ) : (
                                                    filteredAttempts.map((attempt, index) => (
                                                        <tr key={attempt.attemptId || index} className="border-b border-line align-top">
                                                            <td className="py-3 pr-3">
                                                                <div className="font-semibold">{attempt.labName}</div>
                                                                <div className="text-xs text-ink-muted">
                                                                    {getCategoryLabel(attempt.category)} | {attempt.labId}
                                                                </div>
                                                                <div className="text-xs text-ink-muted">
                                                                    {formatAttemptDate(attempt.completedAt)}
                                                                </div>
                                                            </td>
                                                            <td className="py-3 pr-3">
                                                                <Chip
                                                                    tone={
                                                                        attempt.scoreLevel === 'high'
                                                                            ? 'good'
                                                                            : attempt.scoreLevel === 'medium'
                                                                              ? 'warn'
                                                                              : 'bad'
                                                                    }
                                                                    className="whitespace-nowrap"
                                                                >
                                                                    {attempt.percentageScore}% {attempt.scoreLevel || 'low'}
                                                                </Chip>
                                                                <div className="mt-1 text-xs text-ink-muted">
                                                                    {attempt.totalScore} / {attempt.totalPossibleScore}
                                                                </div>
                                                            </td>
                                                            <td className="py-3 pr-3 text-xs">
                                                                {(attempt.failedConcepts || []).length
                                                                    ? (attempt.failedConcepts || [])
                                                                          .slice(0, 4)
                                                                          .map(
                                                                              (concept) =>
                                                                                  `${concept.name} (${concept.failedStepCount})`
                                                                          )
                                                                          .join(', ')
                                                                    : 'None'}
                                                            </td>
                                                            <td className="py-3 text-xs">
                                                                {(attempt.failedQuestions || []).length ? (
                                                                    <div className="flex flex-wrap gap-1.5">
                                                                        {(attempt.failedQuestions || [])
                                                                            .slice(0, 5)
                                                                            .map((question, qIndex) => (
                                                                                <span
                                                                                    key={qIndex}
                                                                                    className="rounded-full border border-line-strong bg-surface-soft px-2 py-0.5"
                                                                                    title={(question.failedValidationSteps || [])
                                                                                        .map((step) => step.description)
                                                                                        .join('; ')}
                                                                                >
                                                                                    {question.questionTitle} (
                                                                                    {question.failedValidationSteps.length} steps)
                                                                                </span>
                                                                            ))}
                                                                    </div>
                                                                ) : (
                                                                    'None'
                                                                )}
                                                            </td>
                                                        </tr>
                                                    ))
                                                )}
                                            </tbody>
                                        </table>
                                    </div>
                                </CardContent>
                            </Card>

                            <Card>
                                <CardContent>
                                    <h3 className="mb-3 text-lg font-semibold">Weak-Area Summary</h3>
                                    <div id="weakAreaSummary">
                                        {weakConcepts.length === 0 && weakQuestions.length === 0 ? (
                                            <div className="text-sm text-ink-muted">
                                                No weak areas yet. Nice work so far.
                                            </div>
                                        ) : (
                                            <div className="flex flex-col gap-3">
                                                {weakConcepts.map((item) => (
                                                    <div key={item.name}>
                                                        <div className="text-sm font-semibold">{item.name}</div>
                                                        <div className="text-xs text-ink-muted">
                                                            {item.count} failed appearances
                                                        </div>
                                                    </div>
                                                ))}
                                                {weakQuestions.length > 0 ? (
                                                    <div>
                                                        <div className="text-sm font-semibold">
                                                            Most Failed Questions
                                                        </div>
                                                        {weakQuestions.map((item) => (
                                                            <div key={item.name} className="text-xs text-ink-muted">
                                                                {item.name} ({item.count})
                                                            </div>
                                                        ))}
                                                    </div>
                                                ) : null}
                                            </div>
                                        )}
                                    </div>
                                </CardContent>
                            </Card>
                        </div>
                    </div>
                ) : null}
            </section>

            {/* Features */}
            <section id="features" className="mt-14">
                <div className="mb-6 text-center">
                    <h2 className="text-2xl font-bold tracking-tight">Key Features</h2>
                    <p className="mt-1 text-sm text-ink-secondary">
                        Everything you need to prepare for your Kubernetes certification exams
                    </p>
                </div>
                <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
                    {FEATURES.map((feature) => (
                        <Card key={feature.title} className="transition-transform hover:-translate-y-0.5">
                            <CardContent>
                                <feature.icon aria-hidden className="mb-3 text-primary" size={26} />
                                <h3 className="mb-1.5 text-base font-semibold">{feature.title}</h3>
                                <p className="text-sm text-ink-secondary">{feature.text}</p>
                                <div className="mt-3 flex flex-wrap gap-1.5">
                                    {feature.tags.map((tag) => (
                                        <Chip key={tag} tone="muted">
                                            {tag}
                                        </Chip>
                                    ))}
                                </div>
                            </CardContent>
                        </Card>
                    ))}
                </div>
            </section>

            {/* Lab-prep overlay */}
            {overlay.visible ? (
                <div
                    id="loadingOverlay"
                    className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
                    role="status"
                >
                    <Card className="w-full max-w-[520px]">
                        <CardContent className="p-6 text-center">
                            <h2 className="mb-4 text-xl font-bold">Preparing Your Lab Environment</h2>
                            <div className="mb-3 h-2 w-full overflow-hidden rounded-full bg-surface-soft">
                                <div
                                    id="progressBar"
                                    className="h-full rounded-full bg-primary transition-[width] duration-300"
                                    style={{ width: `${overlay.progress}%` }}
                                />
                            </div>
                            <div id="loadingMessage" className="text-sm text-ink-secondary">
                                {overlay.message}
                            </div>
                            {overlay.examInfo ? (
                                <div id="examInfo" className="mt-1 text-sm text-ink-muted">
                                    {overlay.examInfo}
                                </div>
                            ) : null}
                            <hr className="my-4 border-line" />
                            <p className="text-xs text-ink-muted">
                                Lab environment setup may take 3-5 minutes. Please wait patiently. Once
                                preparation is complete, you'll be automatically redirected to the exam
                                interface.
                            </p>
                        </CardContent>
                    </Card>
                </div>
            ) : null}

            {/* Exam selection modal */}
            {selectionOpen ? (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
                    <div
                        id="examSelectionModal"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="examSelectionModalLabel"
                        className="w-full max-w-[650px] rounded-ckx-lg border border-line-strong bg-surface p-6 text-ink shadow-ckx-lg"
                    >
                        <div className="mb-4 flex items-center justify-between">
                            <h2 id="examSelectionModalLabel" className="text-lg font-semibold">
                                Select Your Exam
                            </h2>
                            <button
                                type="button"
                                aria-label="Close"
                                className="rounded-ckx-sm p-1 text-ink-muted hover:bg-surface-soft hover:text-ink"
                                onClick={() => setSelectionOpen(false)}
                            >
                                ×
                            </button>
                        </div>
                        <form id="examSelectionForm" onSubmit={(event) => event.preventDefault()}>
                            <div className="mb-3">
                                <label htmlFor="examCategory" className="mb-1 block text-sm font-medium">
                                    Certification Type
                                </label>
                                <select
                                    className={selectClass}
                                    id="examCategory"
                                    required
                                    value={category}
                                    onChange={(event) => {
                                        const next = event.target.value;
                                        setCategory(next);
                                        const nextLabs = labs.filter((lab) => lab.category === next);
                                        setSelectedLabId(nextLabs[0]?.id || '');
                                    }}
                                >
                                    <option value="">Select certification type</option>
                                    {categories.map((value) => (
                                        <option key={value} value={value}>
                                            {getCategoryLabel(value)}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div className="mb-3">
                                <label htmlFor="examName" className="mb-1 block text-sm font-medium">
                                    Exam
                                </label>
                                <select
                                    className={selectClass}
                                    id="examName"
                                    required
                                    disabled={filteredLabs.length === 0}
                                    value={selectedLabId}
                                    onChange={(event) => setSelectedLabId(event.target.value)}
                                >
                                    <option value="">Select a lab</option>
                                    {filteredLabs.map((lab) => (
                                        <option key={lab.id} value={lab.id}>
                                            {lab.name}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div
                                id="examDescription"
                                className="rounded-ckx border border-line bg-surface-soft p-3 text-sm text-ink-secondary"
                            >
                                {selectedLab ? (
                                    <>
                                        <p>{selectedLab.description || 'No description available.'}</p>
                                        <div className="mt-3 flex flex-wrap gap-4 border-t border-line pt-2 text-xs text-ink-muted">
                                            <span>Difficulty: {selectedLab.difficulty || 'Medium'}</span>
                                            <span>
                                                Exam Time:{' '}
                                                {selectedLab.examDurationInMinutes ||
                                                    selectedLab.estimatedTime ||
                                                    '30'}{' '}
                                                minutes
                                            </span>
                                        </div>
                                    </>
                                ) : filteredLabs.length === 0 ? (
                                    'No labs available for this category.'
                                ) : (
                                    'Select an exam to see its description.'
                                )}
                            </div>
                        </form>
                        <div className="mt-5 flex justify-end gap-2">
                            <Button variant="secondary" onClick={() => setSelectionOpen(false)}>
                                CANCEL
                            </Button>
                            <Button
                                id="startSelectedExam"
                                disabled={!selectedLab || starting}
                                onClick={() => void handleStartSelectedExam()}
                            >
                                START EXAM
                            </Button>
                        </div>
                        <p className="mt-2 text-center text-[0.65rem] text-ink-muted">
                            By clicking on Start exam, you accept our{' '}
                            <a
                                className="underline"
                                href="https://github.com/nishanb/CK-X/blob/master/docs/PRIVACY_POLICY.md"
                                target="_blank"
                                rel="noreferrer"
                            >
                                Privacy Policy
                            </a>
                        </p>
                    </div>
                </div>
            ) : null}

            {/* Active exam warning modal */}
            {warningExam ? (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
                    <div
                        id="activeExamWarningModal"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="activeExamWarningModalLabel"
                        className="w-full max-w-[520px] rounded-ckx-lg border border-line-strong bg-surface p-6 text-ink shadow-ckx-lg"
                    >
                        <div className="mb-4 flex items-center justify-between">
                            <h2 id="activeExamWarningModalLabel" className="text-lg font-semibold">
                                Active Exam Detected
                            </h2>
                            <button
                                type="button"
                                aria-label="Close"
                                className="rounded-ckx-sm p-1 text-ink-muted hover:bg-surface-soft hover:text-ink"
                                onClick={() => setWarningExam(null)}
                            >
                                ×
                            </button>
                        </div>
                        <div className="rounded-ckx border border-line bg-surface-soft p-3 text-sm">
                            <p>You already have an active exam session:</p>
                            <p className="my-1">
                                <strong>{warningExam.info?.name || 'Unknown Exam'}</strong>
                            </p>
                            <p className="mb-0 text-ink-secondary">
                                Only one active exam session can be present at a time.
                            </p>
                        </div>
                        <div className="mt-5 flex flex-wrap justify-end gap-2">
                            <Button
                                size="sm"
                                id="continueSessionBtn"
                                onClick={() => navigate(`/exam.html?id=${warningExam.id}`)}
                            >
                                CONTINUE CURRENT SESSION
                            </Button>
                            <Button
                                size="sm"
                                variant="danger"
                                id="terminateAndProceedBtn"
                                disabled={terminating}
                                onClick={() => void handleTerminateAndProceed()}
                            >
                                {terminating ? 'TERMINATING...' : 'TERMINATE AND PROCEED'}
                            </Button>
                        </div>
                    </div>
                </div>
            ) : null}
        </AppShell>
    );
}
