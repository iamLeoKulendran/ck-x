import { useCallback, useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { usePageTitle } from '@/lib/use-page-title';
import { navigate } from '@/lib/navigation';
import { cn } from '@/lib/utils';
import {
    checkExamStatus,
    evaluateExam,
    fetchCurrentExamInfo,
    fetchExamData,
    getExamId,
    submitMcqAnswers,
    terminateSession,
    trackExamEvent,
    type ExamInfo
} from './exam-api';
import {
    getQuestionWeight,
    isMcqQuestion,
    isMultiSelect,
    processQuestionContent,
    removeEstimatedTime,
    transformQuestionsFromApi,
    type ExamQuestion
} from './question-content';
import { DesktopPanel, type DesktopPanelHandle, type StatusType } from './DesktopPanel';
import { TerminalPanel, type TerminalPanelHandle } from './TerminalPanel';

// React port of exam.html + js/exam.js and its component modules. Same
// endpoints, localStorage keys (ckx-exam-paused:/ckx-exam-progress:),
// timer semantics (thresholds at 30/10/0 minutes, warning under 5), pause
// overlay, MCQ mode, review mode, and keyboard shortcuts.

interface ToastMessage {
    id: number;
    text: string;
    tone: 'info' | 'warn' | 'danger' | 'dark';
}

type StartModalVariant = 'new' | 'in-progress' | 'completed';

type Phase =
    | { kind: 'loading' }
    | { kind: 'completed-gate'; status: string }
    | { kind: 'ready' };

function formatTimerSeconds(totalSeconds: number): string {
    const safeSeconds = Math.max(0, Math.floor(totalSeconds));
    const minutes = Math.floor(safeSeconds / 60);
    const seconds = safeSeconds % 60;
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

// Port of timer-service.js calculateRemainingTime (minutes)
function calculateRemainingTime(examInfo: ExamInfo): number {
    if (!examInfo.info?.examDurationInMinutes) return 120;
    if (examInfo.info?.events?.examEndTime) return 0;
    if (examInfo.info?.events?.examStartTime) {
        let startTime = examInfo.info.events.examStartTime;
        if (typeof startTime === 'string') startTime = parseInt(startTime, 10);
        const durationMs = examInfo.info.examDurationInMinutes * 60 * 1000;
        const elapsedMs = Date.now() - (startTime as number);
        const remainingMs = Math.max(0, durationMs - elapsedMs);
        return Math.ceil(remainingMs / (60 * 1000));
    }
    return examInfo.info.examDurationInMinutes;
}

function requestFullscreenSafe(element: Element) {
    element.requestFullscreen?.().catch(() => {});
}

let wakeLock: WakeLockSentinel | null = null;
async function acquireWakeLock() {
    try {
        if ('wakeLock' in navigator) {
            wakeLock = await navigator.wakeLock.request('screen');
        }
    } catch {
        wakeLock = null;
    }
}
async function releaseWakeLock() {
    try {
        await wakeLock?.release();
    } catch {
        // ignore
    }
    wakeLock = null;
}

let nextToastId = 1;

export function ExamPage() {
    usePageTitle('Exam | CK-X');

    const examIdRef = useRef<string | null>(null);
    const examInfoRef = useRef<ExamInfo>({});
    const [examName, setExamName] = useState('Loading exam...');
    const [phase, setPhase] = useState<Phase>({ kind: 'loading' });
    const [loaderVisible, setLoaderVisible] = useState(true);
    const [reviewMode, setReviewMode] = useState(false);
    const reviewModeRef = useRef(false);
    reviewModeRef.current = reviewMode;
    const [questions, setQuestions] = useState<ExamQuestion[]>([]);
    const questionsRef = useRef<ExamQuestion[]>([]);
    questionsRef.current = questions;
    const [currentQuestionId, setCurrentQuestionId] = useState<string | number>('1');
    const currentQuestionIdRef = useRef<string | number>('1');
    currentQuestionIdRef.current = currentQuestionId;

    // ---------- toasts (self-contained, mirrors legacy showToast) ----------
    const [toasts, setToasts] = useState<ToastMessage[]>([]);
    const showToast = useCallback((text: string, tone: ToastMessage['tone'] = 'info', delay = 5000) => {
        const id = nextToastId++;
        setToasts((current) => [...current, { id, text, tone }]);
        setTimeout(() => {
            setToasts((current) => current.filter((t) => t.id !== id));
        }, delay);
    }, []);

    // ---------- connection status ----------
    const [desktopStatus, setDesktopStatus] = useState<{ message: string; type: StatusType; visible: boolean }>({
        message: 'Connecting to Desktop...',
        type: 'info',
        visible: false
    });
    const [globalStatus, setGlobalStatus] = useState<{ message: string; type: StatusType }>({
        message: 'Desktop not connected',
        type: 'info'
    });
    const [sshStatus, setSshStatus] = useState<{ message: string; type: StatusType; visible: boolean }>({
        message: 'Connecting to SSH...',
        type: 'info',
        visible: false
    });
    const desktopStatusTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
    const showDesktopStatus = useCallback((message: string, type: StatusType) => {
        setDesktopStatus({ message, type, visible: true });
        setGlobalStatus({ message, type });
        if (desktopStatusTimer.current) clearTimeout(desktopStatusTimer.current);
        if (type === 'success') {
            desktopStatusTimer.current = setTimeout(() => {
                setDesktopStatus((current) => ({ ...current, visible: false }));
            }, 3000);
        }
    }, []);
    const sshStatusTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
    const showSshStatus = useCallback((message: string, type: StatusType) => {
        setSshStatus({ message, type, visible: true });
        if (sshStatusTimer.current) clearTimeout(sshStatusTimer.current);
        if (type === 'success') {
            sshStatusTimer.current = setTimeout(() => {
                setSshStatus((current) => ({ ...current, visible: false }));
            }, 3000);
        }
    }, []);

    // ---------- storage keys ----------
    const pauseKey = () => `ckx-exam-paused:${examIdRef.current || 'current'}`;
    const progressKey = () => `ckx-exam-progress:${examIdRef.current || 'current'}`;

    function isMcqExam() {
        return examInfoRef.current?.info?.config?.examType === 'mcq';
    }

    // ---------- timer ----------
    const [timerVisible, setTimerVisible] = useState(true);
    const [timerSeconds, setTimerSeconds] = useState<number | null>(null);
    const timerSecondsRef = useRef<number>(0);
    const timerIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
    const processedThresholdsRef = useRef<Set<number>>(new Set());
    const [isExamPaused, setIsExamPaused] = useState(false);
    const isExamPausedRef = useRef(false);
    isExamPausedRef.current = isExamPaused;

    function stopTimerInterval() {
        if (timerIntervalRef.current) {
            clearInterval(timerIntervalRef.current);
            timerIntervalRef.current = null;
        }
    }

    function setTimerDisplay(totalSeconds: number) {
        timerSecondsRef.current = totalSeconds;
        setTimerSeconds(totalSeconds);
    }

    function startTimerInterval(fromSeconds: number) {
        stopTimerInterval();
        setTimerDisplay(Math.max(0, fromSeconds));
        timerIntervalRef.current = setInterval(() => {
            const next = timerSecondsRef.current - 1;
            setTimerDisplay(next);
            if (next <= 0) {
                stopTimerInterval();
                localStorage.removeItem(pauseKey());
                handleExamEnd();
                return;
            }
            const minutes = Math.floor(next / 60);
            const seconds = next % 60;
            if (seconds === 0 && [30, 10].includes(minutes) && !processedThresholdsRef.current.has(minutes)) {
                processedThresholdsRef.current.add(minutes);
                if (minutes === 30) showToast('30 minutes left in your exam', 'warn', 7000);
                if (minutes === 10) showToast('Only 10 minutes remaining! ', 'danger', 10000);
            }
        }, 1000);
    }

    // ---------- pause ----------
    function pauseExam(remainingSeconds = timerSecondsRef.current) {
        if (reviewMode || remainingSeconds <= 0) return;
        stopTimerInterval();
        setTimerDisplay(remainingSeconds);
        localStorage.setItem(
            pauseKey(),
            JSON.stringify({ remainingSeconds, pausedAt: Date.now() })
        );
        setIsExamPaused(true);
    }

    function resumeExam() {
        const secondsToResume = timerSecondsRef.current;
        localStorage.removeItem(pauseKey());
        setIsExamPaused(false);
        if (secondsToResume > 0) startTimerInterval(secondsToResume);
    }

    function restorePausedExamIfNeeded() {
        const savedPause = localStorage.getItem(pauseKey());
        if (!savedPause) return false;
        try {
            const parsed = JSON.parse(savedPause) as { remainingSeconds?: number };
            const remainingSeconds = Number(parsed.remainingSeconds);
            if (Number.isFinite(remainingSeconds) && remainingSeconds > 0) {
                pauseExam(remainingSeconds);
                return true;
            }
        } catch {
            localStorage.removeItem(pauseKey());
        }
        return false;
    }

    // ---------- question progress persistence ----------
    function persistQuestionProgress(nextQuestions?: ExamQuestion[], nextCurrentId?: string | number) {
        const list = nextQuestions ?? questionsRef.current;
        // Ref, not state: mount-scoped handlers (keyboard shortcuts) would
        // otherwise capture reviewMode=false and persist read-only state
        if (reviewModeRef.current || !list.length) return;
        try {
            const answers: Record<string, number[]> = {};
            list.forEach((question) => {
                if ((question.selectedOptions || []).length > 0) {
                    answers[String(question.id)] = question.selectedOptions.map(Number);
                }
            });
            localStorage.setItem(
                progressKey(),
                JSON.stringify({
                    currentQuestionId: String(nextCurrentId ?? currentQuestionIdRef.current),
                    answered: list.filter((q) => q.answered).map((q) => String(q.id)),
                    flagged: list.filter((q) => q.flagged).map((q) => String(q.id)),
                    answers,
                    savedAt: Date.now()
                })
            );
        } catch (error) {
            console.warn('Failed to persist question progress:', error);
        }
    }

    function restoreQuestionProgress(list: ExamQuestion[]): {
        questions: ExamQuestion[];
        currentId: string | number;
    } {
        const fallback = { questions: list, currentId: list[0]?.id ?? '1' };
        const saved = localStorage.getItem(progressKey());
        if (!saved) return fallback;
        try {
            const state = JSON.parse(saved) as {
                currentQuestionId?: string;
                answered?: string[];
                flagged?: string[];
                answers?: Record<string, number[]>;
            };
            const answered = new Set((state.answered || []).map(String));
            const flagged = new Set((state.flagged || []).map(String));
            const savedAnswers = state.answers || {};
            const restored = list.map((question) => {
                const id = String(question.id);
                return {
                    ...question,
                    answered: answered.has(id) || question.answered,
                    flagged: flagged.has(id) || question.flagged,
                    selectedOptions: Array.isArray(savedAnswers[id])
                        ? savedAnswers[id]!.map(Number)
                        : question.selectedOptions
                };
            });
            let currentId = restored[0]?.id ?? '1';
            if (
                state.currentQuestionId &&
                restored.some((q) => String(q.id) === String(state.currentQuestionId))
            ) {
                currentId = state.currentQuestionId;
            }
            return { questions: restored, currentId };
        } catch {
            localStorage.removeItem(progressKey());
            return fallback;
        }
    }

    // ---------- question state helpers ----------
    function updateQuestion(questionId: string | number, patch: (q: ExamQuestion) => ExamQuestion) {
        setQuestions((current) => {
            const next = current.map((q) =>
                String(q.id) === String(questionId) ? patch(q) : q
            );
            persistQuestionProgress(next);
            return next;
        });
    }

    function markQuestionAnswered(questionId: string | number) {
        updateQuestion(questionId, (q) => ({ ...q, answered: true }));
    }

    function toggleQuestionFlag(questionId: string | number) {
        updateQuestion(questionId, (q) => ({ ...q, flagged: !q.flagged }));
    }

    function goToQuestion(questionId: string | number) {
        setCurrentQuestionId(questionId);
        currentQuestionIdRef.current = questionId;
        persistQuestionProgress(undefined, questionId);
    }

    function goToOffset(offset: number) {
        const list = questionsRef.current;
        const index = list.findIndex((q) => String(q.id) === String(currentQuestionIdRef.current));
        const nextIndex = index + offset;
        if (nextIndex >= 0 && nextIndex < list.length) {
            goToQuestion(list[nextIndex]!.id);
        }
    }

    function collectMcqAnswers(): Record<string, number[]> {
        const answers: Record<string, number[]> = {};
        questionsRef.current.forEach((question) => {
            answers[String(question.id)] = (question.selectedOptions || []).map(Number);
        });
        return answers;
    }

    // ---------- modals ----------
    const [startModal, setStartModal] = useState<{ open: boolean; variant: StartModalVariant }>({
        open: false,
        variant: 'new'
    });
    const [startCountdown, setStartCountdown] = useState(3);
    const [confirmEndOpen, setConfirmEndOpen] = useState(false);
    const [terminateOpen, setTerminateOpen] = useState(false);
    const [pauseModalOpen, setPauseModalOpen] = useState(false);
    const [endModalOpen, setEndModalOpen] = useState(false);
    const [helpOpen, setHelpOpen] = useState(false);

    // ---------- panels ----------
    const [terminalActive, setTerminalActive] = useState(false);
    const [desktopActive, setDesktopActive] = useState(false);
    const desktopRef = useRef<DesktopPanelHandle | null>(null);
    const terminalRef = useRef<TerminalPanelHandle | null>(null);
    const [questionPanelPct, setQuestionPanelPct] = useState(40);
    const mainRef = useRef<HTMLDivElement | null>(null);

    // ---------- menus ----------
    const [openMenu, setOpenMenu] = useState<string | null>(null);
    const [questionMenuOpen, setQuestionMenuOpen] = useState(false);

    // ---------- bootstrap ----------
    const bootedRef = useRef(false);
    useEffect(() => {
        if (bootedRef.current) return;
        bootedRef.current = true;
        const examId = getExamId();
        if (!examId) return;
        examIdRef.current = examId;
        void (async () => {
            try {
                const status = await checkExamStatus(examId);
                if (status === 'EVALUATED' || status === 'EVALUATING') {
                    setLoaderVisible(false);
                    setPhase({ kind: 'completed-gate', status });
                    return;
                }
                const info = await fetchCurrentExamInfo();
                examInfoRef.current = info;
                setExamName(info?.info?.name || info?.info?.id || 'Exam session');
                const data = await fetchExamData(examId);
                if (data.info) {
                    examInfoRef.current = { ...info, info: { ...info.info, ...data.info } };
                }
                const transformed = transformQuestionsFromApi(data);
                const restored = restoreQuestionProgress(transformed);
                setQuestions(restored.questions);
                questionsRef.current = restored.questions;
                setCurrentQuestionId(restored.currentId);
                currentQuestionIdRef.current = restored.currentId;
                setPhase({ kind: 'ready' });
                setLoaderVisible(false);
                const events = info?.info?.events;
                if (events?.examStartTime) {
                    setStartModal({
                        open: true,
                        variant: events.examEndTime ? 'completed' : 'in-progress'
                    });
                } else {
                    setStartCountdown(3);
                    setStartModal({ open: true, variant: 'new' });
                }
            } catch (error) {
                console.error('Error loading exam:', error);
                alert('Failed to load exam data. Please refresh the page or contact support.');
                setLoaderVisible(false);
            }
        })();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // ---------- review mode (completed exams) ----------
    async function connectToCompletedSession() {
        const examId = examIdRef.current!;
        setReviewMode(true);
        setPhase({ kind: 'ready' });
        setLoaderVisible(true);
        try {
            const [info, data] = await Promise.all([fetchCurrentExamInfo(), fetchExamData(examId)]);
            examInfoRef.current = info;
            setExamName(info?.info?.name || info?.info?.id || 'Exam session');
            setTimerVisible(false);
            const transformed = transformQuestionsFromApi(data);
            setQuestions(transformed);
            questionsRef.current = transformed;
            setCurrentQuestionId(transformed[0]?.id ?? '1');
            setDesktopActive(true);
                setTimeout(() => setLoaderVisible(false), 1500);
        } catch (error) {
            console.error('Error loading exam environment:', error);
            alert('Failed to connect to exam environment. Please try again.');
            setLoaderVisible(false);
        }
    }

    // ---------- start ----------
    function beginExam() {
        setStartModal({ open: false, variant: startModal.variant });
        setLoaderVisible(true);
        requestFullscreenSafe(document.documentElement);
        void acquireWakeLock();

        if (isMcqExam()) {
            document.body.classList.add('mcq-mode');
        } else {
            setDesktopActive(true);
        }

        const remainingMinutes = calculateRemainingTime(examInfoRef.current);
        if (remainingMinutes <= 0 || examInfoRef.current.info?.events?.examEndTime) {
            setTimerVisible(false);
        } else {
            setTimerVisible(true);
            processedThresholdsRef.current.clear();
            startTimerInterval(remainingMinutes * 60);
            restorePausedExamIfNeeded();
        }

        // Track exam start only for brand-new exams
        const examId = examIdRef.current;
        if (examId && !examInfoRef.current.info?.events?.examStartTime) {
            void trackExamEvent(examId, {
                examStartTime: Date.now(),
                userAgent: navigator.userAgent,
                screenResolution: `${window.screen.width}x${window.screen.height}`
            });
        }
        setTimeout(() => setLoaderVisible(false), 1500);
    }

    function handleStartButton() {
        if (startModal.variant === 'new') {
            const next = startCountdown - 1;
            if (next > 0) {
                setStartCountdown(next);
                return;
            }
        }
        beginExam();
    }

    // ---------- end / terminate ----------
    function trackExamEndEvent() {
        const examId = examIdRef.current;
        if (!examId) return Promise.resolve(undefined);
        return trackExamEvent(examId, { examEndTime: Date.now() });
    }

    function submitForEvaluation(examId: string) {
        return isMcqExam()
            ? submitMcqAnswers(examId, collectMcqAnswers())
            : evaluateExam(examId);
    }

    // Timer reached zero
    function handleExamEnd() {
        localStorage.removeItem(pauseKey());
        localStorage.removeItem(progressKey());
        setIsExamPaused(false);
        void releaseWakeLock();
        setEndModalOpen(true);
        const examId = examIdRef.current;
        if (!examId) return;
        void trackExamEndEvent()
            .then(() => submitForEvaluation(examId))
            .then((data) => console.log('Exam evaluation started:', data))
            .catch((error) => {
                console.error('Error ending exam:', error);
                alert('There was an error evaluating your exam. Please try manually ending the exam.');
            });
    }

    function handleConfirmEnd() {
        setLoaderVisible(true);
        setConfirmEndOpen(false);
        void releaseWakeLock();
        const examId = examIdRef.current;
        if (!examId) return;
        void trackExamEndEvent()
            .then(() => submitForEvaluation(examId))
            .then((data) => {
                console.log('Exam evaluation started:', data);
                stopTimerInterval();
                localStorage.removeItem(pauseKey());
                localStorage.removeItem(progressKey());
                setTimeout(() => {
                    navigate(`/results?id=${examId}`);
                }, 3000);
            })
            .catch((error) => {
                console.error('Error ending exam:', error);
                setLoaderVisible(false);
                alert('There was an error ending your exam. Please try again or contact support.');
            });
    }

    function handleConfirmTerminate() {
        setLoaderVisible(true);
        setTerminateOpen(false);
        void releaseWakeLock();
        const examId = examIdRef.current;
        if (!examId) return;
        terminateSession(examId)
            .then(() => {
                stopTimerInterval();
                localStorage.removeItem(pauseKey());
                localStorage.removeItem(progressKey());
                navigate('/');
            })
            .catch((error) => {
                console.error('Error terminating session:', error);
                alert('Failed to terminate session. Please try again or contact support.');
                setLoaderVisible(false);
            });
    }

    // ---------- keyboard shortcuts ----------
    useEffect(() => {
        function onKeyDown(event: KeyboardEvent) {
            if (event.ctrlKey || event.metaKey || event.altKey) return;
            const target = event.target as HTMLElement | null;
            const isTextInput =
                target?.tagName === 'INPUT' &&
                !['radio', 'checkbox'].includes((target as HTMLInputElement).type);
            const isTypingContext =
                target &&
                (isTextInput ||
                    target.tagName === 'TEXTAREA' ||
                    target.tagName === 'SELECT' ||
                    target.isContentEditable ||
                    target.closest?.('.ssh-terminal-container, .terminal-container'));
            const modalOpen = document.querySelector('[role="dialog"]');
            if (isTypingContext || modalOpen || isExamPausedRef.current || !questionsRef.current.length) {
                return;
            }
            switch (event.key) {
                case '[':
                    event.preventDefault();
                    goToOffset(-1);
                    break;
                case ']':
                    event.preventDefault();
                    goToOffset(1);
                    break;
                case 'f':
                case 'F':
                    event.preventDefault();
                    toggleQuestionFlag(currentQuestionIdRef.current);
                    break;
                case 'd':
                case 'D':
                    event.preventDefault();
                    markQuestionAnswered(currentQuestionIdRef.current);
                    break;
                case '?':
                    event.preventDefault();
                    showToast(
                        'Keyboard shortcuts — [ previous question, ] next question, F flag for review, D mark as done, ? this help.',
                        'dark',
                        8000
                    );
                    break;
                default:
                    break;
            }
        }
        document.addEventListener('keydown', onKeyDown);
        return () => document.removeEventListener('keydown', onKeyDown);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // ---------- clipboard copy (click .inline-code) ----------
    useEffect(() => {
        function onClick(event: MouseEvent) {
            const target = event.target as HTMLElement | null;
            if (target && target.matches?.('.inline-code')) {
                const codeText = target.textContent || '';
                try {
                    void fetch('/facilitator/api/v1/remote-desktop/clipboard', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ content: codeText })
                    });
                } catch {
                    // non-critical
                }
                navigator.clipboard?.writeText(codeText).catch(() => {});
            }
        }
        document.addEventListener('click', onClick);
        return () => document.removeEventListener('click', onClick);
    }, []);

    // ---------- cleanup ----------
    useEffect(() => {
        return () => {
            void releaseWakeLock();
            stopTimerInterval();
            document.body.classList.remove('mcq-mode', 'exam-is-paused');
        };
         
    }, []);

    useEffect(() => {
        document.body.classList.toggle('exam-is-paused', isExamPaused);
    }, [isExamPaused]);

    // ---------- panel divider drag ----------
    function onDividerPointerDown(event: React.PointerEvent) {
        event.preventDefault();
        const main = mainRef.current;
        if (!main) return;
        const rect = main.getBoundingClientRect();
        function onMove(moveEvent: PointerEvent) {
            const pct = ((moveEvent.clientX - rect.left) / rect.width) * 100;
            setQuestionPanelPct(Math.min(70, Math.max(20, pct)));
        }
        function onUp() {
            window.removeEventListener('pointermove', onMove);
            window.removeEventListener('pointerup', onUp);
        }
        window.addEventListener('pointermove', onMove);
        window.addEventListener('pointerup', onUp);
    }

    // ---------- derived ----------
    const currentQuestion =
        questions.find((q) => String(q.id) === String(currentQuestionId)) || null;
    const currentIndex = questions.findIndex((q) => String(q.id) === String(currentQuestionId));
    const answeredCount = questions.filter((q) => q.answered).length;
    const flaggedCount = questions.filter((q) => q.flagged).length;
    const totalMarks = examInfoRef.current?.info?.config?.totalMarks ?? null;
    const isMcq = isMcqExam();

    const menuItemClass =
        'block w-full rounded-ckx-sm px-3 py-1.5 text-left text-sm text-ink-secondary hover:bg-surface-soft hover:text-ink';

    function menuButton(id: string, label: string) {
        return (
            <button
                type="button"
                id={id}
                className="rounded-ckx-sm border border-line-strong bg-surface-soft px-3 py-1.5 text-sm text-ink-secondary hover:text-ink"
                aria-expanded={openMenu === id}
                onClick={() => setOpenMenu((current) => (current === id ? null : id))}
            >
                {label} ▾
            </button>
        );
    }

    return (
        <div className="flex h-screen min-h-0 flex-col overflow-hidden bg-canvas text-ink">
            {/* Loader */}
            {loaderVisible ? (
                <div
                    id="pageLoader"
                    role="status"
                    className="fixed inset-0 z-[70] flex items-center justify-center bg-black/80"
                >
                    <div className="h-10 w-10 animate-spin rounded-full border-2 border-line-strong border-t-primary" />
                </div>
            ) : null}

            {/* Paused overlay */}
            {isExamPaused ? (
                <div
                    id="examPausedOverlay"
                    className="fixed inset-0 z-[60] flex items-center justify-center bg-black/85 p-4"
                >
                    <div className="w-full max-w-[420px] rounded-ckx-lg border border-line-strong bg-surface p-6 text-center">
                        <div className="text-xs font-semibold uppercase tracking-wide text-warn">
                            Exam Paused
                        </div>
                        <h2 className="mt-2 text-xl font-bold">Timer paused</h2>
                        <p className="mt-2 text-sm text-ink-secondary">
                            Your environment is still running. Resume when you are ready to continue.
                        </p>
                        <Button id="resumeExamOverlayBtn" className="mt-4" onClick={resumeExam}>
                            Resume Exam
                        </Button>
                    </div>
                </div>
            ) : null}

            {/* Toasts */}
            <div className="fixed right-4 top-16 z-[65] flex w-80 max-w-[calc(100vw-2rem)] flex-col gap-2">
                {toasts.map((toast) => (
                    <div
                        key={toast.id}
                        role="alert"
                        className={cn(
                            'rounded-ckx border p-3 text-sm shadow-ckx-lg',
                            toast.tone === 'warn' && 'border-warn bg-warn-soft text-ink',
                            toast.tone === 'danger' && 'border-bad bg-bad-soft text-ink',
                            (toast.tone === 'info' || toast.tone === 'dark') &&
                                'border-line-strong bg-surface-raised text-ink'
                        )}
                    >
                        {toast.text}
                    </div>
                ))}
            </div>

            {/* Header */}
            <header className="flex flex-wrap items-center justify-between gap-3 border-b border-line bg-surface px-4 py-2">
                <div className="flex items-center gap-4">
                    <div>
                        <div className="flex items-center gap-2 text-base font-bold">
                            CK-X
                            {reviewMode ? (
                                <span className="rounded-full bg-primary-soft px-2 py-0.5 text-[0.65rem] font-semibold text-primary-ink">
                                    Review Mode
                                </span>
                            ) : null}
                        </div>
                        <div className="text-xs text-ink-muted">Practice Exam Mode</div>
                    </div>
                    {timerVisible ? (
                        <div
                            id="examTimer"
                            className={cn(
                                'rounded-ckx border border-line-strong bg-surface-soft px-3 py-1 font-mono text-lg font-semibold',
                                timerSeconds !== null && timerSeconds < 300 && 'border-bad text-bad'
                            )}
                        >
                            {formatTimerSeconds(timerSeconds ?? 0)}
                        </div>
                    ) : null}
                </div>
                <div className="min-w-0">
                    <div className="text-[0.65rem] uppercase tracking-wide text-ink-muted">
                        Current exam
                    </div>
                    <div id="examNameDisplay" className="truncate text-sm font-medium" title={examName}>
                        {examName}
                    </div>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                    {reviewMode ? (
                        <Button
                            size="sm"
                            onClick={() => navigate(`/results?id=${examIdRef.current}`)}
                        >
                            View Results
                        </Button>
                    ) : (
                        <button
                            type="button"
                            id="pauseExamBtn"
                            className={cn(
                                'rounded-ckx-sm border px-3 py-1.5 text-sm',
                                isExamPaused
                                    ? 'border-warn text-warn'
                                    : 'border-line-strong text-ink-secondary hover:text-ink'
                            )}
                            onClick={() => (isExamPaused ? resumeExam() : setPauseModalOpen(true))}
                        >
                            {isExamPaused ? 'Resume Exam' : 'Pause Exam'}
                        </button>
                    )}
                    <div
                        id="globalConnectionState"
                        className="flex items-center gap-1.5 text-xs text-ink-muted"
                    >
                        <span
                            className={cn(
                                'inline-block h-2 w-2 rounded-full',
                                globalStatus.type === 'success' && 'bg-good',
                                globalStatus.type === 'error' && 'bg-bad',
                                globalStatus.type === 'info' && 'bg-ink-muted'
                            )}
                        />
                        <span id="globalConnectionText">{globalStatus.message}</span>
                    </div>

                    <div className="relative">
                        {menuButton('examInterfaceDropdown', 'Exam Interface')}
                        {openMenu === 'examInterfaceDropdown' ? (
                            <div className="absolute right-0 z-50 mt-1 w-64 rounded-ckx border border-line-strong bg-surface p-1 shadow-ckx-lg">
                                <button
                                    type="button"
                                    id="resizeTerminalBtn"
                                    className={menuItemClass}
                                    onClick={() => {
                                        setQuestionPanelPct(40);
                                        setOpenMenu(null);
                                    }}
                                >
                                    Reset panel width
                                </button>
                                <button
                                    type="button"
                                    id="fullscreenBtn"
                                    className={menuItemClass}
                                    onClick={() => {
                                        if (document.fullscreenElement) {
                                            document.exitFullscreen?.().catch(() => {});
                                        } else {
                                            requestFullscreenSafe(document.documentElement);
                                        }
                                        setOpenMenu(null);
                                    }}
                                >
                                    Toggle page fullscreen
                                </button>
                                <hr className="my-1 border-line" />
                                <button
                                    type="button"
                                    id="toggleViewBtn"
                                    className={menuItemClass}
                                    onClick={() => {
                                        const next = !terminalActive;
                                        setTerminalActive(next);
                                        setOpenMenu(null);
                                        if (next) {
                                            showToast(
                                                'Note: In the actual certification exam, only remote desktop access is available. Terminal access is provided here for practice convenience.',
                                                'info',
                                                8000
                                            );
                                            setTimeout(() => terminalRef.current?.resize(), 300);
                                        }
                                    }}
                                >
                                    {terminalActive
                                        ? 'Switch back to Remote Desktop'
                                        : 'Switch to CK-X terminal helper'}
                                </button>
                                <hr className="my-1 border-line" />
                                <button
                                    type="button"
                                    className={menuItemClass}
                                    onClick={() => {
                                        setHelpOpen(true);
                                        setOpenMenu(null);
                                    }}
                                >
                                    Open Exam Mode help
                                </button>
                            </div>
                        ) : null}
                    </div>

                    <div className="relative">
                        {menuButton('examControlsDropdown', 'Exam Controls')}
                        {openMenu === 'examControlsDropdown' ? (
                            <div className="absolute right-0 z-50 mt-1 w-64 rounded-ckx border border-line-strong bg-surface p-1 shadow-ckx-lg">
                                {!reviewMode ? (
                                    <button
                                        type="button"
                                        id="endExamBtnDropdown"
                                        className={menuItemClass}
                                        onClick={() => {
                                            setConfirmEndOpen(true);
                                            setOpenMenu(null);
                                        }}
                                    >
                                        Submit for evaluation
                                    </button>
                                ) : null}
                                <button
                                    type="button"
                                    id="pauseExamMenuBtn"
                                    className={menuItemClass}
                                    onClick={() => {
                                        setOpenMenu(null);
                                        if (isExamPaused) resumeExam();
                                        else setPauseModalOpen(true);
                                    }}
                                >
                                    {isExamPaused ? 'Resume Exam' : 'Pause Exam'}
                                </button>
                                <button
                                    type="button"
                                    id="reconnectDesktopMenuBtn"
                                    className={menuItemClass}
                                    onClick={() => {
                                        desktopRef.current?.reconnect();
                                        setOpenMenu(null);
                                    }}
                                >
                                    Reconnect Desktop (safe)
                                </button>
                                <button
                                    type="button"
                                    className={cn(menuItemClass, 'cursor-not-allowed opacity-50')}
                                    disabled
                                    title="Safe reset is planned for a later phase."
                                >
                                    Reset environment (coming soon)
                                </button>
                                <hr className="my-1 border-line" />
                                <button
                                    type="button"
                                    id="terminateSessionBtn"
                                    className={cn(menuItemClass, 'text-bad hover:text-bad')}
                                    onClick={() => {
                                        setTerminateOpen(true);
                                        setOpenMenu(null);
                                    }}
                                >
                                    Terminate active exam session
                                </button>
                            </div>
                        ) : null}
                    </div>

                    <div className="relative">
                        {menuButton('examInfoDropdown', 'Exam Information')}
                        {openMenu === 'examInfoDropdown' ? (
                            <div className="absolute right-0 z-50 mt-1 w-64 rounded-ckx border border-line-strong bg-surface p-1 shadow-ckx-lg">
                                <button
                                    type="button"
                                    className={menuItemClass}
                                    onClick={() => {
                                        setHelpOpen(true);
                                        setOpenMenu(null);
                                    }}
                                >
                                    ReadMe and exam help
                                </button>
                                <a
                                    className={menuItemClass}
                                    href="https://kubernetes.io/docs/home/"
                                    target="_blank"
                                    rel="noreferrer"
                                >
                                    Kubernetes Documentation
                                </a>
                            </div>
                        ) : null}
                    </div>
                </div>
            </header>

            {/* Main */}
            <div ref={mainRef} id="mainContainer" className="flex min-h-0 flex-1">
                {/* Question panel */}
                <div
                    id="questionPanel"
                    className="flex min-h-0 flex-col overflow-y-auto border-r border-line bg-surface p-4"
                    style={{ width: isMcq ? '100%' : `${questionPanelPct}%` }}
                >
                    <div className="mb-3 flex items-start justify-between gap-2">
                        <div>
                            <div className="text-[0.65rem] uppercase tracking-wide text-ink-muted">
                                Tasks
                            </div>
                            <div className="text-sm font-semibold">Question workspace</div>
                        </div>
                        <div
                            id="questionProgress"
                            aria-live="polite"
                            className="text-xs text-ink-muted"
                        >
                            {questions.length
                                ? `${answeredCount} / ${questions.length} done${flaggedCount ? ` | ${flaggedCount} flagged` : ''}`
                                : '0 / 0 answered'}
                        </div>
                    </div>

                    {/* Question navigation */}
                    <div className="mb-3 flex items-center gap-2">
                        <button
                            type="button"
                            id="prevBtn"
                            aria-label="Previous question"
                            disabled={currentIndex <= 0}
                            className="rounded-ckx-sm border border-line-strong px-3 py-1.5 text-sm disabled:opacity-40"
                            onClick={() => goToOffset(-1)}
                        >
                            &lt;
                        </button>
                        <div className="relative flex-1">
                            <button
                                type="button"
                                id="questionDropdown"
                                aria-expanded={questionMenuOpen}
                                className="w-full rounded-ckx-sm border border-line-strong bg-surface-soft px-3 py-1.5 text-sm"
                                onClick={() => setQuestionMenuOpen((open) => !open)}
                            >
                                {currentQuestion?.title || `Question ${currentQuestionId}`} ▾
                            </button>
                            {questionMenuOpen ? (
                                <div
                                    id="questionDropdownMenu"
                                    className="absolute z-50 mt-1 max-h-72 w-full overflow-y-auto rounded-ckx border border-line-strong bg-surface p-1 shadow-ckx-lg"
                                >
                                    {questions.map((question) => (
                                        <button
                                            key={question.id}
                                            type="button"
                                            data-question={question.id}
                                            className={cn(
                                                menuItemClass,
                                                'flex items-center justify-between',
                                                String(question.id) === String(currentQuestionId) &&
                                                    'bg-primary-soft text-primary-ink'
                                            )}
                                            onClick={() => {
                                                goToQuestion(question.id);
                                                setQuestionMenuOpen(false);
                                            }}
                                        >
                                            <span>Question {question.id}</span>
                                            <span className="flex gap-1">
                                                {question.answered ? (
                                                    <span className="rounded-full bg-good-soft px-1.5 text-[0.6rem] font-semibold text-good">
                                                        Done
                                                    </span>
                                                ) : null}
                                                {question.flagged ? (
                                                    <span className="rounded-full bg-warn-soft px-1.5 text-[0.6rem] font-semibold text-warn">
                                                        Flag
                                                    </span>
                                                ) : null}
                                            </span>
                                        </button>
                                    ))}
                                </div>
                            ) : null}
                        </div>
                        <button
                            type="button"
                            id="nextBtn"
                            aria-label="Next question"
                            disabled={currentIndex >= questions.length - 1}
                            className="rounded-ckx-sm border border-line-strong px-3 py-1.5 text-sm disabled:opacity-40"
                            onClick={() => goToOffset(1)}
                        >
                            &gt;
                        </button>
                    </div>

                    {/* Question content */}
                    <div id="questionContent" className="flex min-h-0 flex-1 flex-col">
                        {reviewMode ? (
                            <div className="mb-3 rounded-ckx border border-line bg-surface-soft p-3 text-sm text-ink-secondary">
                                Review Mode: This exam has been completed. You can review questions and
                                your environment.
                            </div>
                        ) : null}
                        {currentQuestion ? (
                            <QuestionView
                                question={currentQuestion}
                                totalMarks={totalMarks}
                                reviewMode={reviewMode}
                                onFlag={() => toggleQuestionFlag(currentQuestion.id)}
                                onDone={() => markQuestionAnswered(currentQuestion.id)}
                                onNext={() => goToOffset(1)}
                                onSelectOptions={(selected) =>
                                    updateQuestion(currentQuestion.id, (q) => ({
                                        ...q,
                                        selectedOptions: selected,
                                        answered: selected.length > 0
                                    }))
                                }
                            />
                        ) : phase.kind === 'ready' ? (
                            <div className="rounded-ckx border border-bad bg-bad-soft p-3 text-sm">
                                Question not found. Please try another question.
                            </div>
                        ) : null}
                    </div>
                </div>

                {/* Divider + desktop/terminal panel (hidden in MCQ mode) */}
                {!isMcq ? (
                    <>
                        <div
                            id="panelDivider"
                            role="separator"
                            aria-orientation="vertical"
                            title="Drag to resize"
                            className="w-1.5 shrink-0 cursor-col-resize bg-line hover:bg-primary"
                            onPointerDown={onDividerPointerDown}
                            onDoubleClick={() => setQuestionPanelPct(40)}
                        />
                        <div id="vncPanel" className="flex min-h-0 min-w-0 flex-1 flex-col">
                            <div
                                className="terminal-container flex min-h-0 flex-1 flex-col"
                                style={{ display: terminalActive ? 'none' : 'flex' }}
                            >
                                <div className="flex flex-wrap items-center justify-between gap-2 border-b border-line bg-surface px-3 py-2">
                                    <div>
                                        <div className="text-sm font-semibold">Remote Desktop</div>
                                        <div className="text-xs text-ink-muted">
                                            Connect inside the desktop with{' '}
                                            <span className="inline-code">ssh ckad9999</span>
                                        </div>
                                    </div>
                                    <div className="flex gap-2">
                                        <button
                                            type="button"
                                            id="reconnectVncBtn"
                                            title="Reload the VNC iframe only. This is non-destructive."
                                            className="rounded-ckx-sm border border-line-strong px-2.5 py-1 text-xs text-ink-secondary hover:text-ink"
                                            onClick={() => desktopRef.current?.reconnect()}
                                        >
                                            Reconnect Desktop
                                        </button>
                                        <button
                                            type="button"
                                            id="fullscreenVncBtn"
                                            title="Open the remote desktop iframe fullscreen"
                                            className="rounded-ckx-sm border border-line-strong px-2.5 py-1 text-xs text-ink-secondary hover:text-ink"
                                            onClick={() => desktopRef.current?.fullscreen()}
                                        >
                                            Fullscreen
                                        </button>
                                    </div>
                                </div>
                                <DesktopPanel
                                    ref={desktopRef}
                                    active={desktopActive}
                                    onStatus={showDesktopStatus}
                                />
                                <div className="flex flex-wrap justify-between gap-2 border-t border-line bg-surface px-3 py-1.5 text-[0.7rem] text-ink-muted">
                                    <span>
                                        <strong>Copy/paste:</strong> click highlighted task text to copy,
                                        then use Ctrl+Shift+V in the desktop terminal.
                                    </span>
                                    <span>
                                        <strong>Reconnect Desktop:</strong> safe iframe reconnect only; it
                                        does not reset Kubernetes work.
                                    </span>
                                </div>
                                {desktopStatus.visible ? (
                                    <div
                                        id="connectionStatus"
                                        className={cn(
                                            'px-3 py-1 text-xs',
                                            desktopStatus.type === 'success' && 'bg-good-soft text-good',
                                            desktopStatus.type === 'error' && 'bg-bad-soft text-bad',
                                            desktopStatus.type === 'info' &&
                                                'bg-surface-soft text-ink-secondary'
                                        )}
                                    >
                                        {desktopStatus.message}
                                    </div>
                                ) : null}
                            </div>

                            {/* Terminal helper */}
                            <div
                                className="flex min-h-0 flex-1 flex-col"
                                style={{ display: terminalActive ? 'flex' : 'none' }}
                            >
                                <div className="flex flex-wrap items-center justify-between gap-2 border-b border-line bg-surface px-3 py-2">
                                    <div>
                                        <div className="text-sm font-semibold">CK-X Terminal Helper</div>
                                        <div className="text-xs text-ink-muted">
                                            Practice convenience only. The remote desktop remains the
                                            primary exam workspace.
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        id="fullscreenTerminalBtn"
                                        className="rounded-ckx-sm border border-line-strong px-2.5 py-1 text-xs text-ink-secondary hover:text-ink"
                                        onClick={() => terminalRef.current?.fullscreen()}
                                    >
                                        Fullscreen
                                    </button>
                                </div>
                                <TerminalPanel
                                    ref={terminalRef}
                                    visible={terminalActive}
                                    onStatus={showSshStatus}
                                />
                                {sshStatus.visible ? (
                                    <div
                                        id="sshConnectionStatus"
                                        className={cn(
                                            'px-3 py-1 text-xs',
                                            sshStatus.type === 'success' && 'bg-good-soft text-good',
                                            sshStatus.type === 'error' && 'bg-bad-soft text-bad',
                                            sshStatus.type === 'info' && 'bg-surface-soft text-ink-secondary'
                                        )}
                                    >
                                        {sshStatus.message}
                                    </div>
                                ) : null}
                            </div>
                        </div>
                    </>
                ) : null}
            </div>

            {/* Help drawer */}
            {helpOpen ? (
                <div className="fixed inset-0 z-[55]" role="dialog" aria-modal="true" aria-label="Exam Mode Help">
                    <div className="absolute inset-0 bg-black/50" onClick={() => setHelpOpen(false)} />
                    <div
                        id="examHelpDrawer"
                        className="absolute right-0 top-0 h-full w-[min(420px,90vw)] overflow-y-auto border-l border-line-strong bg-surface p-5"
                    >
                        <div className="mb-4 flex items-start justify-between">
                            <div>
                                <div className="text-[0.65rem] uppercase tracking-wide text-ink-muted">
                                    ReadMe
                                </div>
                                <h2 className="text-lg font-semibold">Exam Mode Help</h2>
                            </div>
                            <button
                                type="button"
                                aria-label="Close"
                                className="rounded-ckx-sm p-1 text-ink-muted hover:text-ink"
                                onClick={() => setHelpOpen(false)}
                            >
                                ×
                            </button>
                        </div>
                        {[
                            ['Practice workflow', 'This is a CK-X practice layout inspired by performance-based exam workflows. It is not an exact copy of any official exam interface.'],
                            ['Target host', 'Run Kubernetes work from the remote desktop terminal with ssh ckad9999. Plain kubectl should work after you connect.'],
                            ['Copy and paste', 'Click highlighted command text in the task panel to copy it. In the desktop terminal, use Ctrl+Shift+V to paste and Ctrl+Shift+C to copy.'],
                            ['Reconnect Desktop', 'Reconnect Desktop reloads only the VNC frame. It is non-destructive and does not reset Kubernetes resources or previous attempts.'],
                            ['Pause and reset', 'Pause Exam stops only the browser countdown until you resume. Environment reset is shown as coming soon because no safe reset backend is enabled in this UI phase.'],
                            ['Be careful with the session', 'Avoid refreshing or closing the browser during an exam unless needed. Terminate Session ends the active environment and should only be used when you are finished or intentionally abandoning the attempt.']
                        ].map(([title, text]) => (
                            <div
                                key={title}
                                className="mb-3 rounded-ckx border border-line bg-surface-soft p-3"
                            >
                                <h3 className="mb-1 text-sm font-semibold">{title}</h3>
                                <p className="text-xs text-ink-secondary">{text}</p>
                            </div>
                        ))}
                    </div>
                </div>
            ) : null}

            {/* Start exam modal */}
            {startModal.open ? (
                <ModalShell
                    title={
                        startModal.variant === 'new'
                            ? 'Ready to Begin Your Exam'
                            : startModal.variant === 'completed'
                              ? 'Exam Completed'
                              : 'Exam in Progress'
                    }
                >
                    {startModal.variant === 'new' ? (
                        <div className="text-sm text-ink-secondary">
                            <div className="mb-3 rounded-ckx border border-good bg-good-soft p-3 text-ink">
                                <strong>Important:</strong> Please treat this as a real exam. Focus on
                                completing tasks accurately and efficiently as you would in a
                                certification exam.
                            </div>
                            <p>When you click "Start Exam", the following will happen:</p>
                            <ul className="my-2 list-disc pl-5">
                                <li>Your exam timer will begin counting down.</li>
                                <li>You will be connected to the Kubernetes environment.</li>
                                <li>The application will enter fullscreen mode</li>
                                <li>
                                    When you click on the <span className="inline-code">highlighted</span>{' '}
                                    content, it will be copied to the clipboard.
                                </li>
                                <li>
                                    Keyboard shortcuts: <span className="inline-code">[</span> previous,{' '}
                                    <span className="inline-code">]</span> next,{' '}
                                    <span className="inline-code">F</span> flag,{' '}
                                    <span className="inline-code">D</span> done,{' '}
                                    <span className="inline-code">?</span> help.
                                </li>
                            </ul>
                            <p className="mb-0">Are you ready to start?</p>
                        </div>
                    ) : startModal.variant === 'completed' ? (
                        <div className="text-sm text-ink-secondary">
                            <div className="mb-3 rounded-ckx border border-line bg-surface-soft p-3">
                                <strong>Note:</strong> You've already completed this exam session.
                            </div>
                            <p>
                                Your session is still available. You can continue to view the
                                environment, but your answers have already been submitted.
                            </p>
                        </div>
                    ) : (
                        <div className="text-sm text-ink-secondary">
                            <div className="mb-3 rounded-ckx border border-warn bg-warn-soft p-3 text-ink">
                                <strong>Note:</strong> You already have an exam in progress.
                            </div>
                            <p>Your previous session will be restored, including your remaining time.</p>
                            <p>You can continue where you left off.</p>
                        </div>
                    )}
                    <div className="mt-5 flex justify-end">
                        <Button id="startExamBtn" onClick={handleStartButton}>
                            {startModal.variant === 'new'
                                ? `Start Exam (${startCountdown})`
                                : startModal.variant === 'completed'
                                  ? 'Continue to Session'
                                  : 'Continue Session'}
                        </Button>
                    </div>
                </ModalShell>
            ) : null}

            {/* Completed-exam gate modal */}
            {phase.kind === 'completed-gate' ? (
                <ModalShell
                    title={phase.status === 'EVALUATED' ? 'Exam Complete' : 'Exam Being Evaluated'}
                >
                    <div className="text-sm text-ink-secondary">
                        {phase.status === 'EVALUATED' ? (
                            <p>This exam has been completed and your results are ready to view.</p>
                        ) : (
                            <>
                                <p>This exam has been completed and is currently being evaluated.</p>
                                <p>You can view the results once evaluation is complete.</p>
                            </>
                        )}
                        <p className="mt-2">
                            You can still connect to your exam environment to review your work.
                        </p>
                    </div>
                    <div className="mt-5 flex justify-end">
                        <Button id="connectToSessionBtn" onClick={() => void connectToCompletedSession()}>
                            Connect to Session
                        </Button>
                    </div>
                </ModalShell>
            ) : null}

            {/* Pause modal */}
            {pauseModalOpen ? (
                <ModalShell title="Pause Exam?" onClose={() => setPauseModalOpen(false)}>
                    <p className="text-sm text-ink-secondary">
                        Pause the current exam timer? You can resume later.
                    </p>
                    <p className="mt-1 text-sm text-ink-muted">
                        This does not terminate the session, reset Kubernetes, or delete your work.
                    </p>
                    <div className="mt-5 flex justify-end gap-2">
                        <Button variant="secondary" onClick={() => setPauseModalOpen(false)}>
                            Cancel
                        </Button>
                        <Button
                            id="confirmPauseExamBtn"
                            onClick={() => {
                                setPauseModalOpen(false);
                                pauseExam();
                            }}
                        >
                            Pause Timer
                        </Button>
                    </div>
                </ModalShell>
            ) : null}

            {/* End exam confirm modal */}
            {confirmEndOpen ? (
                <ModalShell title="End Exam Confirmation" onClose={() => setConfirmEndOpen(false)}>
                    <p className="text-sm text-ink-secondary">
                        Are you sure you want to end the exam? This action cannot be undone.
                    </p>
                    <div className="mt-2 rounded-ckx border border-good bg-good-soft p-3 text-sm">
                        <p className="mb-1 font-semibold">What happens next:</p>
                        <ul className="list-disc pl-5">
                            <li>Your submissions will be evaluated.</li>
                            <li>You will be redirected to the results page.</li>
                            <li>Your session will remain intact until you choose to terminate it.</li>
                        </ul>
                    </div>
                    <div className="mt-5 flex justify-end">
                        <Button id="confirmEndBtn" variant="danger" onClick={handleConfirmEnd}>
                            End Exam
                        </Button>
                    </div>
                </ModalShell>
            ) : null}

            {/* Terminate modal */}
            {terminateOpen ? (
                <ModalShell title="Terminate Session Warning" onClose={() => setTerminateOpen(false)}>
                    <div className="rounded-ckx border border-warn bg-warn-soft p-3 text-sm text-ink">
                        <h3 className="mb-1 font-semibold">Warning!</h3>
                        <p>Terminating this session will:</p>
                        <ul className="my-1 list-disc pl-5">
                            <li>Immediately clean up all environment resources</li>
                            <li>End your exam without evaluating your answers</li>
                        </ul>
                        <p>
                            This action <strong>cannot</strong> be undone.
                        </p>
                    </div>
                    <p className="mt-2 text-sm text-ink-secondary">
                        Would you like to proceed with terminating this session?
                    </p>
                    <div className="mt-5 flex justify-end gap-2">
                        <Button variant="secondary" onClick={() => setTerminateOpen(false)}>
                            Cancel
                        </Button>
                        <Button id="confirmTerminateBtn" variant="danger" onClick={handleConfirmTerminate}>
                            Terminate Session
                        </Button>
                    </div>
                </ModalShell>
            ) : null}

            {/* Time-up modal */}
            {endModalOpen ? (
                <ModalShell title="Exam Time Complete">
                    <div className="mb-3 rounded-ckx border border-line bg-surface-soft p-3 text-sm">
                        <strong>Time's up! ⏳ Your exam has ended. </strong>
                    </div>
                    <p className="text-sm text-ink-secondary">We're now evaluating your results.</p>
                    <p className="text-sm text-ink-secondary">
                        Your environment session will remain available for review until you choose to
                        end it.
                    </p>
                    <div className="mt-5 flex justify-end">
                        <Button
                            id="viewResultsBtn"
                            onClick={() => navigate(`/results?id=${examIdRef.current}`)}
                        >
                            View Results
                        </Button>
                    </div>
                </ModalShell>
            ) : null}
        </div>
    );
}

function ModalShell({
    title,
    children,
    onClose
}: {
    title: string;
    children: React.ReactNode;
    onClose?: () => void;
}) {
    return (
        <div className="fixed inset-0 z-[75] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
            <div
                role="dialog"
                aria-modal="true"
                aria-label={title}
                className="w-full max-w-[520px] rounded-ckx-lg border border-line-strong bg-surface p-6 text-ink shadow-ckx-lg"
            >
                <div className="mb-4 flex items-center justify-between">
                    <h2 className="text-lg font-semibold">{title}</h2>
                    {onClose ? (
                        <button
                            type="button"
                            aria-label="Close"
                            className="rounded-ckx-sm p-1 text-ink-muted hover:text-ink"
                            onClick={onClose}
                        >
                            ×
                        </button>
                    ) : null}
                </div>
                {children}
            </div>
        </div>
    );
}

// One question: pack-authored body rendered as HTML (legacy parity), MCQ
// options and action buttons as React elements.
function QuestionView({
    question,
    totalMarks,
    reviewMode,
    onFlag,
    onDone,
    onNext,
    onSelectOptions
}: {
    question: ExamQuestion;
    totalMarks: number | null;
    reviewMode: boolean;
    onFlag: () => void;
    onDone: () => void;
    onNext: () => void;
    onSelectOptions: (selected: number[]) => void;
}) {
    const mcq = isMcqQuestion(question);
    const originalData = question.originalData || {};
    const machineHostname = originalData.machineHostname || 'N/A';
    const namespace = originalData.namespace || 'N/A';
    const concepts = (originalData.concepts || []).join(', ') || 'Not specified';
    const bodyHtml = processQuestionContent(removeEstimatedTime(question.content));
    const multi = isMultiSelect(question);
    const selected = new Set((question.selectedOptions || []).map(Number));

    function toggleOption(index: number) {
        if (multi) {
            const next = new Set(selected);
            if (next.has(index)) next.delete(index);
            else next.add(index);
            onSelectOptions([...next].sort((a, b) => a - b));
        } else {
            onSelectOptions([index]);
        }
    }

    return (
        <div className="flex min-h-0 flex-1 flex-col">
            <div className="mb-3">
                <div className="flex items-start justify-between gap-2">
                    <div>
                        <div className="text-[0.65rem] uppercase tracking-wide text-ink-muted">
                            Question {question.id}
                        </div>
                        <div className="text-sm font-semibold">
                            {mcq ? (
                                'Choose the correct answer(s) below'
                            ) : (
                                <>
                                    Complete this task on{' '}
                                    <span className="inline-code">ssh {machineHostname}</span>
                                </>
                            )}
                        </div>
                    </div>
                    <span
                        className={cn(
                            'rounded-full px-2.5 py-0.5 text-xs font-semibold',
                            question.answered ? 'bg-good-soft text-good' : 'bg-surface-soft text-ink-muted'
                        )}
                    >
                        {question.answered ? 'Done' : 'Open'}
                    </span>
                </div>
                <div className="mt-2 flex flex-wrap gap-4 rounded-ckx border border-line bg-surface-soft p-2.5 text-xs">
                    <div>
                        <span className="text-ink-muted">Question Weight</span>{' '}
                        <strong>{getQuestionWeight(question, totalMarks)}</strong>
                    </div>
                    {mcq ? (
                        <div>
                            <span className="text-ink-muted">Domain</span>{' '}
                            <strong>{originalData.domain || 'N/A'}</strong>
                        </div>
                    ) : (
                        <div>
                            <span className="text-ink-muted">Namespace</span> <strong>{namespace}</strong>
                        </div>
                    )}
                    <div>
                        <span className="text-ink-muted">Concepts</span> <strong>{concepts}</strong>
                    </div>
                    {question.flagged ? (
                        <div className="font-semibold text-warn">Flagged for review</div>
                    ) : null}
                </div>
            </div>

            <div className="mb-1 text-xs font-semibold uppercase tracking-wide text-ink-muted">
                {mcq ? 'Question' : 'Task'}
            </div>
            <div
                className="question-body text-sm leading-relaxed"
                dangerouslySetInnerHTML={{ __html: bodyHtml }}
            />

            {mcq ? (
                <>
                    <div className="mb-1 mt-4 text-xs font-semibold uppercase tracking-wide text-ink-muted">
                        {multi ? 'Select all that apply' : 'Select one answer'}
                    </div>
                    <ul className="flex flex-col gap-1.5" data-mcq-question={question.id}>
                        {(originalData.options || []).map((option, index) => (
                            <li key={index}>
                                <label
                                    className="flex cursor-pointer items-start gap-2 rounded-ckx border border-line bg-surface-soft p-2.5 text-sm hover:border-line-strong"
                                    htmlFor={`mcq-q${question.id}-opt${index}`}
                                >
                                    <input
                                        type={multi ? 'checkbox' : 'radio'}
                                        id={`mcq-q${question.id}-opt${index}`}
                                        name={`mcq-q${question.id}`}
                                        value={index}
                                        data-question-id={question.id}
                                        checked={selected.has(index)}
                                        onChange={() => toggleOption(index)}
                                        className="mt-0.5"
                                    />
                                    <span
                                        dangerouslySetInnerHTML={{
                                            __html: processQuestionContent(option)
                                        }}
                                    />
                                </label>
                            </li>
                        ))}
                    </ul>
                </>
            ) : null}

            {!reviewMode ? (
                <div className="action-buttons-container mt-auto pt-4">
                    <div className="flex flex-wrap gap-2">
                        <button
                            type="button"
                            id="flagQuestionBtn"
                            className={cn(
                                'rounded-ckx-sm border px-3 py-1.5 text-sm',
                                question.flagged
                                    ? 'border-warn text-warn'
                                    : 'border-line-strong text-ink-secondary hover:text-ink'
                            )}
                            onClick={onFlag}
                        >
                            {question.flagged ? 'Flagged' : 'Flag for review'}
                        </button>
                        <button
                            type="button"
                            id="markDoneBtn"
                            className={cn(
                                'rounded-ckx-sm border px-3 py-1.5 text-sm',
                                question.answered
                                    ? 'border-good text-good'
                                    : 'border-line-strong text-ink-secondary hover:text-ink'
                            )}
                            onClick={onDone}
                        >
                            {question.answered ? 'Marked done' : 'Mark as done'}
                        </button>
                        <button
                            type="button"
                            id="nextQuestionBtn"
                            className="rounded-ckx-sm bg-primary px-3 py-1.5 text-sm font-medium text-white"
                            onClick={onNext}
                        >
                            Next question →
                        </button>
                    </div>
                </div>
            ) : null}
        </div>
    );
}
