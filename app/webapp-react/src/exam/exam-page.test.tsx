import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { getQueryParam, navigate } from '@/lib/navigation';
import { ExamPage } from './ExamPage';

// Everything network/socket/terminal is mocked. Evaluate/terminate/events
// only ever see fixture exam ids — never the live facilitator.

vi.mock('@/lib/navigation', () => ({
    navigate: vi.fn(),
    openInNewTab: vi.fn(),
    getQueryParam: vi.fn(() => 'exam-1')
}));

vi.mock('socket.io-client', () => ({
    io: vi.fn(() => ({
        on: vi.fn(),
        emit: vi.fn(),
        connect: vi.fn(),
        disconnect: vi.fn(),
        connected: false
    }))
}));

vi.mock('xterm', () => ({
    Terminal: vi.fn(function (this: Record<string, unknown>) {
        this.loadAddon = vi.fn();
        this.open = vi.fn();
        this.onData = vi.fn();
        this.write = vi.fn();
        this.writeln = vi.fn();
        this.dispose = vi.fn();
        this.cols = 80;
        this.rows = 24;
    })
}));

vi.mock('xterm-addon-fit', () => ({
    FitAddon: vi.fn(function (this: Record<string, unknown>) {
        this.fit = vi.fn();
    })
}));

const PERFORMANCE_INFO = {
    id: 'exam-1',
    status: 'READY',
    info: {
        id: 'cka-001',
        name: 'CKA Mock 1',
        examDurationInMinutes: 120,
        events: {},
        config: { examType: 'performance', totalMarks: 100 }
    }
};

const QUESTIONS = {
    questions: [
        {
            id: '1',
            question: 'Create a pod named `web` using image `nginx`.',
            machineHostname: 'ckad9999',
            namespace: 'default',
            concepts: ['pods'],
            weightage: 4
        },
        {
            id: '2',
            question: 'Fix the broken deployment.',
            machineHostname: 'ckad9999',
            namespace: 'apps',
            concepts: ['deployments'],
            weightage: 6
        }
    ]
};

const MCQ_INFO = {
    id: 'exam-1',
    status: 'READY',
    info: {
        id: 'kcna-001',
        name: 'KCNA Mock 1',
        examDurationInMinutes: 90,
        events: {},
        config: { examType: 'mcq', totalMarks: 100 }
    }
};

// Sanitized shape: the facilitator strips correctOptionIndexes (and
// explanation) before serving questions, so multi-select can only come from
// an explicit multiSelect flag. (Known pre-existing gap: shipped packs lack
// the flag, so their multi-answer questions render single-select in BOTH
// frontends until the facilitator exposes multiSelect.)
const MCQ_QUESTIONS = {
    questions: [
        {
            id: '1',
            question: 'Which component schedules pods?',
            type: 'multiple-choice',
            domain: 'Architecture',
            options: ['kube-scheduler', 'kubelet', 'etcd'],
            weightage: 5
        },
        {
            id: '2',
            question: 'Select the control-plane components.',
            type: 'multiple-choice',
            domain: 'Architecture',
            options: ['kube-apiserver', 'kube-proxy', 'etcd'],
            multiSelect: true,
            weightage: 5
        }
    ]
};

function jsonResponse(body: unknown, ok = true, status = ok ? 200 : 500) {
    return { ok, status, json: () => Promise.resolve(body) } as Response;
}

const fetchMock = vi.fn();

function examRoutes({
    status = 'READY',
    info = PERFORMANCE_INFO,
    questions = QUESTIONS
}: {
    status?: string;
    info?: unknown;
    questions?: unknown;
} = {}) {
    const calls: { url: string; options?: RequestInit | undefined }[] = [];
    fetchMock.mockImplementation((url: string, options?: RequestInit) => {
        calls.push({ url, options });
        if (url === '/facilitator/api/v1/exams/exam-1/status')
            return Promise.resolve(jsonResponse({ status }));
        if (url === '/facilitator/api/v1/exams/current')
            return Promise.resolve(jsonResponse(info));
        if (url === '/facilitator/api/v1/exams/exam-1/questions')
            return Promise.resolve(jsonResponse(questions));
        if (url === '/facilitator/api/v1/exams/exam-1/events')
            return Promise.resolve(jsonResponse({}));
        if (url === '/facilitator/api/v1/exams/exam-1/evaluate')
            return Promise.resolve(jsonResponse({}));
        if (url === '/facilitator/api/v1/exams/exam-1/mcq-submit')
            return Promise.resolve(jsonResponse({}));
        if (url === '/facilitator/api/v1/exams/exam-1/terminate')
            return Promise.resolve(jsonResponse({}));
        if (url === '/api/vnc-info')
            return Promise.resolve(jsonResponse({ defaultPassword: 'pw' }));
        if (url === '/facilitator/api/v1/remote-desktop/clipboard')
            return Promise.resolve(jsonResponse({}));
        return Promise.reject(new Error(`Unexpected fetch: ${url}`));
    });
    return calls;
}

function renderPage() {
    return render(
        <ThemeProvider>
            <ExamPage />
        </ThemeProvider>
    );
}

// Click through the 3-click start countdown of a fresh exam
async function startFreshExam(user: ReturnType<typeof userEvent.setup>) {
    await waitFor(() =>
        expect(screen.getByText('Ready to Begin Your Exam')).toBeInTheDocument()
    );
    const startBtn = document.getElementById('startExamBtn') as HTMLElement;
    expect(startBtn.textContent).toContain('Start Exam (3)');
    await user.click(startBtn);
    expect(startBtn.textContent).toContain('Start Exam (2)');
    await user.click(startBtn);
    expect(startBtn.textContent).toContain('Start Exam (1)');
    await user.click(startBtn);
    await waitFor(() =>
        expect(screen.queryByText('Ready to Begin Your Exam')).not.toBeInTheDocument()
    );
}

beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
    fetchMock.mockReset();
    localStorage.clear();
    vi.mocked(getQueryParam).mockReturnValue('exam-1');
    vi.spyOn(window, 'alert').mockImplementation(() => {});
});

afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
    vi.useRealTimers();
});

describe('ExamPage bootstrap', () => {
    it('redirects to the dashboard when no exam id is present', async () => {
        vi.mocked(getQueryParam).mockReturnValue(null);
        renderPage();
        await waitFor(() => expect(navigate).toHaveBeenCalledWith('/'));
        expect(window.alert).toHaveBeenCalledWith(
            'Error: No exam ID provided. Please return to the dashboard.'
        );
    });

    it('shows the completed modal for EVALUATED exams and enters review mode', async () => {
        examRoutes({ status: 'EVALUATED' });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Exam Complete')).toBeInTheDocument());
        await user.click(screen.getByRole('button', { name: 'Connect to Session' }));

        await waitFor(() => expect(screen.getByText('Review Mode')).toBeInTheDocument());
        // Timer hidden, review banner present, View Results available
        expect(document.getElementById('examTimer')).not.toBeInTheDocument();
        expect(screen.getByText(/Review Mode: This exam has been completed/)).toBeInTheDocument();
        expect(screen.getByRole('button', { name: 'View Results' })).toBeInTheDocument();
    });

    it('never persists question progress from shortcuts in review mode', async () => {
        examRoutes({ status: 'EVALUATED' });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Exam Complete')).toBeInTheDocument());
        await user.click(screen.getByRole('button', { name: 'Connect to Session' }));
        await waitFor(() => expect(screen.getByText('Review Mode')).toBeInTheDocument());

        fireEvent.keyDown(document.body, { key: 'd' });
        fireEvent.keyDown(document.body, { key: 'f' });
        expect(localStorage.getItem('ckx-exam-progress:exam-1')).toBeNull();
    });
});

describe('ExamPage fresh performance exam', () => {
    it('runs the start countdown, shows the timer and first question, tracks start', async () => {
        const calls = examRoutes();
        const user = userEvent.setup();
        renderPage();

        await startFreshExam(user);

        expect(document.getElementById('examTimer')?.textContent).toBe('120:00');
        expect(screen.getByText(/Question Weight/)).toBeInTheDocument();
        expect(document.getElementById('questionContent')?.innerHTML).toContain('web');
        expect(document.getElementById('questionContent')?.textContent).toContain('ssh ckad9999');
        expect(document.getElementById('examNameDisplay')?.textContent).toBe('CKA Mock 1');

        const eventCall = calls.find((c) => c.url.endsWith('/events'));
        expect(eventCall).toBeTruthy();
        const body = JSON.parse(String(eventCall!.options?.body)) as {
            events: { examStartTime?: number };
        };
        expect(typeof body.events.examStartTime).toBe('number');
    });

    it('navigates questions, flags, marks done, and persists progress', async () => {
        examRoutes();
        const user = userEvent.setup();
        renderPage();
        await startFreshExam(user);

        // Question 1 → flag it
        await user.click(document.getElementById('flagQuestionBtn') as HTMLElement);
        expect(screen.getByText('Flagged for review')).toBeInTheDocument();

        // Mark done, go next
        await user.click(document.getElementById('markDoneBtn') as HTMLElement);
        expect(document.getElementById('questionProgress')?.textContent).toContain('1 / 2 done');
        await user.click(document.getElementById('nextBtn') as HTMLElement);
        expect(document.getElementById('questionContent')?.innerHTML).toContain('broken deployment');
        expect(document.getElementById('prevBtn')).toBeEnabled();
        expect(document.getElementById('nextBtn')).toBeDisabled();

        const saved = JSON.parse(localStorage.getItem('ckx-exam-progress:exam-1') || '{}') as {
            currentQuestionId?: string;
            answered?: string[];
            flagged?: string[];
        };
        expect(saved.currentQuestionId).toBe('2');
        expect(saved.answered).toEqual(['1']);
        expect(saved.flagged).toEqual(['1']);
    });

    it('restores saved progress on load', async () => {
        localStorage.setItem(
            'ckx-exam-progress:exam-1',
            JSON.stringify({
                currentQuestionId: '2',
                answered: ['1'],
                flagged: ['2'],
                answers: {},
                savedAt: Date.now()
            })
        );
        examRoutes();
        const user = userEvent.setup();
        renderPage();
        await startFreshExam(user);

        expect(document.getElementById('questionContent')?.innerHTML).toContain('broken deployment');
        expect(document.getElementById('questionProgress')?.textContent).toContain('1 / 2 done');
        expect(document.getElementById('questionProgress')?.textContent).toContain('1 flagged');
    });

    it('supports the [ ] F D keyboard shortcuts', async () => {
        examRoutes();
        const user = userEvent.setup();
        renderPage();
        await startFreshExam(user);

        fireEvent.keyDown(document.body, { key: ']' });
        await waitFor(() =>
            expect(document.getElementById('questionContent')?.innerHTML).toContain(
                'broken deployment'
            )
        );
        fireEvent.keyDown(document.body, { key: '[' });
        await waitFor(() =>
            expect(document.getElementById('questionContent')?.innerHTML).toContain('web')
        );
        fireEvent.keyDown(document.body, { key: 'f' });
        await waitFor(() => expect(screen.getByText('Flagged for review')).toBeInTheDocument());
        fireEvent.keyDown(document.body, { key: 'd' });
        await waitFor(() =>
            expect(document.getElementById('questionProgress')?.textContent).toContain('1 / 2 done')
        );
    });

    it('pauses and resumes the exam with persisted pause state', async () => {
        examRoutes();
        const user = userEvent.setup();
        renderPage();
        await startFreshExam(user);

        await user.click(document.getElementById('pauseExamBtn') as HTMLElement);
        await waitFor(() => expect(screen.getByText('Pause Exam?')).toBeInTheDocument());
        await user.click(document.getElementById('confirmPauseExamBtn') as HTMLElement);

        expect(document.getElementById('examPausedOverlay')).toBeInTheDocument();
        const pauseState = JSON.parse(
            localStorage.getItem('ckx-exam-paused:exam-1') || '{}'
        ) as { remainingSeconds?: number };
        expect(pauseState.remainingSeconds).toBeGreaterThan(0);

        await user.click(document.getElementById('resumeExamOverlayBtn') as HTMLElement);
        expect(document.getElementById('examPausedOverlay')).not.toBeInTheDocument();
        expect(localStorage.getItem('ckx-exam-paused:exam-1')).toBeNull();
    });

    it('restores a paused exam on load', async () => {
        localStorage.setItem(
            'ckx-exam-paused:exam-1',
            JSON.stringify({ remainingSeconds: 3600, pausedAt: Date.now() })
        );
        examRoutes();
        const user = userEvent.setup();
        renderPage();
        await startFreshExam(user);

        expect(document.getElementById('examPausedOverlay')).toBeInTheDocument();
        expect(document.getElementById('examTimer')?.textContent).toBe('60:00');
    });

    it('submit for evaluation tracks the end event, evaluates, and redirects', async () => {
        const calls = examRoutes();
        const user = userEvent.setup();
        renderPage();
        await startFreshExam(user);

        await user.click(document.getElementById('examControlsDropdown') as HTMLElement);
        await user.click(document.getElementById('endExamBtnDropdown') as HTMLElement);
        await waitFor(() => expect(screen.getByText('End Exam Confirmation')).toBeInTheDocument());
        await user.click(document.getElementById('confirmEndBtn') as HTMLElement);

        await waitFor(() => {
            expect(calls.some((c) => c.url.endsWith('/evaluate'))).toBe(true);
        });
        const endEvent = calls
            .filter((c) => c.url.endsWith('/events'))
            .map((c) => JSON.parse(String(c.options?.body)) as { events: Record<string, unknown> })
            .find((b) => 'examEndTime' in b.events);
        expect(endEvent).toBeTruthy();
        expect(localStorage.getItem('ckx-exam-progress:exam-1')).toBeNull();
        await waitFor(() => expect(navigate).toHaveBeenCalledWith('/results?id=exam-1'), {
            timeout: 5000
        });
    }, 10000);

    it('terminate session confirms, terminates, and goes home', async () => {
        const calls = examRoutes();
        const user = userEvent.setup();
        renderPage();
        await startFreshExam(user);

        await user.click(document.getElementById('examControlsDropdown') as HTMLElement);
        await user.click(document.getElementById('terminateSessionBtn') as HTMLElement);
        await waitFor(() =>
            expect(screen.getByText('Terminate Session Warning')).toBeInTheDocument()
        );
        await user.click(document.getElementById('confirmTerminateBtn') as HTMLElement);

        await waitFor(() => expect(calls.some((c) => c.url.endsWith('/terminate'))).toBe(true));
        await waitFor(() => expect(navigate).toHaveBeenCalledWith('/'));
    });
});

describe('ExamPage MCQ exam', () => {
    it('renders options, records selections, and submits mcq answers', async () => {
        const calls = examRoutes({ info: MCQ_INFO, questions: MCQ_QUESTIONS });
        const user = userEvent.setup();
        renderPage();
        await startFreshExam(user);

        // MCQ mode hides the desktop panel
        expect(document.body.classList.contains('mcq-mode')).toBe(true);
        expect(screen.getByText('Select one answer')).toBeInTheDocument();

        await user.click(screen.getByRole('radio', { name: /kube-scheduler/ }));
        expect(document.getElementById('questionProgress')?.textContent).toContain('1 / 2 done');

        // Multi-select question
        await user.click(document.getElementById('nextBtn') as HTMLElement);
        expect(screen.getByText('Select all that apply')).toBeInTheDocument();
        await user.click(screen.getByRole('checkbox', { name: /kube-apiserver/ }));
        await user.click(screen.getByRole('checkbox', { name: /etcd/ }));
        expect(document.getElementById('questionProgress')?.textContent).toContain('2 / 2 done');

        // Submit
        await user.click(document.getElementById('examControlsDropdown') as HTMLElement);
        await user.click(document.getElementById('endExamBtnDropdown') as HTMLElement);
        await user.click(document.getElementById('confirmEndBtn') as HTMLElement);

        await waitFor(() => expect(calls.some((c) => c.url.endsWith('/mcq-submit'))).toBe(true));
        const submit = calls.find((c) => c.url.endsWith('/mcq-submit'))!;
        const body = JSON.parse(String(submit.options?.body)) as {
            answers: Record<string, number[]>;
        };
        expect(body.answers['1']).toEqual([0]);
        expect(body.answers['2']).toEqual([0, 2]);
        expect(calls.some((c) => c.url.endsWith('/evaluate'))).toBe(false);
    }, 10000);
});

describe('ExamPage continue mode', () => {
    it('offers Continue Session for an in-progress exam with remaining time', async () => {
        const startedInfo = {
            ...PERFORMANCE_INFO,
            info: {
                ...PERFORMANCE_INFO.info,
                events: { examStartTime: Date.now() - 60 * 60 * 1000 }
            }
        };
        examRoutes({ info: startedInfo });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Exam in Progress')).toBeInTheDocument());
        const startBtn = document.getElementById('startExamBtn') as HTMLElement;
        expect(startBtn.textContent).toContain('Continue Session');
        await user.click(startBtn);

        await waitFor(() =>
            expect(document.getElementById('examTimer')?.textContent).toBe('60:00')
        );
    });
});
