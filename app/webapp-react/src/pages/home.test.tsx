import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { navigate } from '@/lib/navigation';
import { HomePage } from './HomePage';

// All network I/O mocked; exam creation/termination only ever sees fixture
// ids — never Leo's live facilitator.

vi.mock('@/lib/navigation', () => ({
    navigate: vi.fn(),
    openInNewTab: vi.fn(),
    getQueryParam: vi.fn(() => null)
}));

const LABS = [
    {
        id: 'cka-001',
        name: 'CKA Mock 1',
        category: 'CKA',
        description: 'Cluster admin drill',
        difficulty: 'Hard',
        examDurationInMinutes: 120
    },
    {
        id: 'cks-001',
        name: 'CKS Mock 1',
        category: 'CKS',
        description: 'Security drill',
        difficulty: 'Hard',
        examDurationInMinutes: 120
    }
];

const CERTS = {
    certifications: [
        { code: 'CKA', displayName: 'Certified Kubernetes Administrator' },
        { code: 'CKS', displayName: 'Certified Kubernetes Security Specialist' }
    ]
};

const ATTEMPTS = {
    data: {
        attempts: [
            {
                attemptId: 'a-1',
                examSessionId: 's-1',
                labId: 'cka-001',
                labName: 'CKA Mock 1',
                category: 'CKA',
                completedAt: '2026-07-01T10:00:00.000Z',
                percentageScore: 72,
                totalScore: 72,
                totalPossibleScore: 100,
                scoreLevel: 'medium',
                failedConcepts: [{ name: 'NetworkPolicy', failedStepCount: 2 }],
                failedQuestions: [
                    {
                        questionTitle: 'Question 4',
                        failedValidationSteps: [{ description: 'policy missing' }]
                    }
                ]
            },
            {
                attemptId: 'a-2',
                examSessionId: 's-2',
                labId: 'cks-001',
                labName: 'CKS Mock 1',
                category: 'CKS',
                completedAt: '2026-07-02T10:00:00.000Z',
                percentageScore: 90,
                totalScore: 90,
                totalPossibleScore: 100,
                scoreLevel: 'high',
                failedConcepts: [],
                failedQuestions: []
            }
        ],
        filters: {
            categories: ['CKA', 'CKS'],
            labs: [
                { labId: 'cka-001', labName: 'CKA Mock 1' },
                { labId: 'cks-001', labName: 'CKS Mock 1' }
            ],
            failedConcepts: ['NetworkPolicy']
        }
    }
};

function jsonResponse(body: unknown, ok = true, status = ok ? 200 : 500) {
    return { ok, status, json: () => Promise.resolve(body) } as Response;
}

const fetchMock = vi.fn();

// Default routing used by most tests: no active session, labs+certs+attempts
// resolve with fixtures.
function defaultRoutes(currentResponse: Response = jsonResponse({}, false, 404)) {
    fetchMock.mockImplementation((url: string) => {
        if (url === '/facilitator/api/v1/exams/current') return Promise.resolve(currentResponse);
        if (url === '/facilitator/api/v1/assements/') return Promise.resolve(jsonResponse(LABS));
        if (url === '/facilitator/api/v1/certifications') return Promise.resolve(jsonResponse(CERTS));
        if (url === '/facilitator/api/v1/exams/attempts') return Promise.resolve(jsonResponse(ATTEMPTS));
        return Promise.reject(new Error(`Unexpected fetch: ${url}`));
    });
}

function renderPage() {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    return render(
        <QueryClientProvider client={client}>
            <ThemeProvider>
                <ToastProvider>
                    <HomePage />
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}

beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
    fetchMock.mockReset();
    localStorage.clear();
    vi.spyOn(window, 'alert').mockImplementation(() => {});
});

afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
    vi.useRealTimers();
});

describe('HomePage hero and shell', () => {
    it('renders hero, six stat tiles, features, and the baseline hooks', async () => {
        defaultRoutes();
        renderPage();

        const title = document.querySelector('.command-title');
        expect(title?.textContent).toContain('Local Kubernetes');
        expect(document.getElementById('startExamBtn')).toBeInTheDocument();
        expect(document.querySelectorAll('.hero-stat')).toHaveLength(6);
        expect(screen.getByText('Key Features')).toBeInTheDocument();
        expect(screen.getByText('Real Exam Environment')).toBeInTheDocument();
        await waitFor(() => expect(document.getElementById('attemptsContent')).toBeInTheDocument());
    });
});

describe('HomePage previous attempts', () => {
    it('renders summary cards, table rows, and weak areas from the API', async () => {
        defaultRoutes();
        renderPage();

        await waitFor(() => expect(document.getElementById('attemptsContent')).toBeInTheDocument());
        // Summary: 2 attempts, top weak area NetworkPolicy
        expect(screen.getByText('Top Weak Area')).toBeInTheDocument();
        const summary = document.getElementById('attemptSummaryGrid')!;
        expect(within(summary as HTMLElement).getByText('NetworkPolicy')).toBeInTheDocument();
        // Table row details
        expect(screen.getByText('72% medium')).toBeInTheDocument();
        expect(screen.getByText('NetworkPolicy (2)')).toBeInTheDocument();
        // Weak-area summary panel
        const weakPanel = document.getElementById('weakAreaSummary')!;
        expect(within(weakPanel as HTMLElement).getByText('NetworkPolicy')).toBeInTheDocument();
    });

    it('filters attempts by category and clears filters', async () => {
        defaultRoutes();
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(document.getElementById('attemptsContent')).toBeInTheDocument());
        const tbody = () => within(document.getElementById('attemptsTableBody') as HTMLElement);
        expect(tbody().getByText('CKA Mock 1')).toBeInTheDocument();
        await user.selectOptions(document.getElementById('attemptCategoryFilter') as HTMLElement, 'CKS');
        expect(tbody().queryByText('CKA Mock 1')).not.toBeInTheDocument();
        expect(tbody().getByText('CKS Mock 1')).toBeInTheDocument();

        await user.click(document.getElementById('clearAttemptFiltersBtn') as HTMLElement);
        expect(tbody().getByText('CKA Mock 1')).toBeInTheDocument();
    });

    it('shows the empty state when there is no history', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(jsonResponse({}, false, 404));
            if (url === '/facilitator/api/v1/assements/') return Promise.resolve(jsonResponse(LABS));
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(jsonResponse(CERTS));
            if (url === '/facilitator/api/v1/exams/attempts')
                return Promise.resolve(
                    jsonResponse({ data: { attempts: [], filters: {} } })
                );
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();
        await waitFor(() =>
            expect(screen.getByText(/No previous attempts yet/)).toBeInTheDocument()
        );
    });

    it('shows the error state when the attempts API fails', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(jsonResponse({}, false, 404));
            if (url === '/facilitator/api/v1/assements/') return Promise.resolve(jsonResponse(LABS));
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(jsonResponse(CERTS));
            if (url === '/facilitator/api/v1/exams/attempts')
                return Promise.resolve(jsonResponse({}, false, 500));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();
        await waitFor(() =>
            expect(screen.getByText(/Failed to load previous attempts/)).toBeInTheDocument()
        );
    });
});

describe('HomePage start-exam flow', () => {
    it('opens the selection modal with certification labels when no session is active', async () => {
        defaultRoutes();
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(document.getElementById('attemptsContent')).toBeInTheDocument());
        await user.click(document.getElementById('startExamBtn') as HTMLElement);

        await waitFor(() =>
            expect(document.getElementById('examSelectionModal')).toBeInTheDocument()
        );
        const category = document.getElementById('examCategory') as HTMLSelectElement;
        // CKAD absent → first category selected; labels resolved from /certifications
        expect(category.value).toBe('CKA');
        const labels = Array.from(category.options).map((o) => o.textContent);
        expect(labels).toContain('CKA - Certified Kubernetes Administrator');
        const exam = document.getElementById('examName') as HTMLSelectElement;
        expect(exam.value).toBe('cka-001');
        const description = document.getElementById('examDescription')!;
        expect(description.textContent).toContain('Cluster admin drill');
        expect(description.textContent).toContain('Difficulty: Hard');
        expect(description.textContent).toContain('Exam Time: 120 minutes');
        expect(document.getElementById('startSelectedExam')).toBeEnabled();
    });

    it('creates the exam with the selected lab + userAgent, polls, and redirects', async () => {
        // Real timers: 1s poll interval + 1s READY pause ≈ 2s wall clock.
        const user = userEvent.setup();
        let createdBody: Record<string, unknown> | null = null;
        let statusCalls = 0;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(jsonResponse({}, false, 404));
            if (url === '/facilitator/api/v1/assements/') return Promise.resolve(jsonResponse(LABS));
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(jsonResponse(CERTS));
            if (url === '/facilitator/api/v1/exams/attempts')
                return Promise.resolve(jsonResponse(ATTEMPTS));
            if (url === '/facilitator/api/v1/exams/' && options?.method === 'POST') {
                createdBody = JSON.parse(String(options.body)) as Record<string, unknown>;
                return Promise.resolve(jsonResponse({ id: 'exam-9', warmUpTimeInSeconds: 5 }));
            }
            if (url === '/facilitator/api/v1/exams/exam-9/status') {
                statusCalls += 1;
                return Promise.resolve(
                    jsonResponse({ status: statusCalls >= 2 ? 'READY' : 'PREPARING' })
                );
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await vi.waitFor(() => expect(document.getElementById('attemptsContent')).toBeInTheDocument());
        await user.click(document.getElementById('startExamBtn') as HTMLElement);
        await vi.waitFor(() =>
            expect(document.getElementById('startSelectedExam')).toBeEnabled()
        );
        await user.click(document.getElementById('startSelectedExam') as HTMLElement);

        await waitFor(() => expect(createdBody).not.toBeNull());
        expect(createdBody!.id).toBe('cka-001');
        expect(typeof createdBody!.userAgent).toBe('string');
        await waitFor(() => expect(localStorage.getItem('currentExamId')).toBe('exam-9'));

        // First poll PREPARING, second READY, then a 1s pause before redirect
        await waitFor(() => expect(navigate).toHaveBeenCalledWith('/exam.html?id=exam-9'), {
            timeout: 6000
        });
    }, 10000);

    it('shows the active-exam warning; CONTINUE goes to the running exam', async () => {
        defaultRoutes();
        const user = userEvent.setup();
        renderPage();
        await waitFor(() => expect(document.getElementById('attemptsContent')).toBeInTheDocument());

        // The click-time current check returns an active session
        fetchMock.mockImplementation((url: string) => {
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(
                    jsonResponse({ id: 'exam-5', status: 'READY', info: { name: 'CKA Mock 1' } })
                );
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        await user.click(document.getElementById('startExamBtn') as HTMLElement);

        await waitFor(() =>
            expect(document.getElementById('activeExamWarningModal')).toBeInTheDocument()
        );
        expect(document.getElementById('examSelectionModal')).not.toBeInTheDocument();
        expect(screen.getByText('CKA Mock 1', { selector: 'strong' })).toBeInTheDocument();

        await user.click(screen.getByRole('button', { name: 'CONTINUE CURRENT SESSION' }));
        expect(navigate).toHaveBeenCalledWith('/exam.html?id=exam-5');
    });

    it('TERMINATE AND PROCEED terminates, clears storage, and opens selection', async () => {
        localStorage.setItem('currentExamData', '{"id":"exam-5"}');
        localStorage.setItem('currentExamId', 'exam-5');
        let terminated = false;
        defaultRoutes();
        const user = userEvent.setup();
        renderPage();
        await waitFor(() => expect(document.getElementById('attemptsContent')).toBeInTheDocument());

        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(
                    jsonResponse({ id: 'exam-5', status: 'READY', info: { name: 'CKA Mock 1' } })
                );
            if (url === '/facilitator/api/v1/exams/exam-5/terminate' && options?.method === 'POST') {
                terminated = true;
                return Promise.resolve(jsonResponse({}));
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        await user.click(document.getElementById('startExamBtn') as HTMLElement);
        await waitFor(() =>
            expect(document.getElementById('activeExamWarningModal')).toBeInTheDocument()
        );
        await user.click(screen.getByRole('button', { name: 'TERMINATE AND PROCEED' }));

        await waitFor(() =>
            expect(document.getElementById('examSelectionModal')).toBeInTheDocument()
        );
        expect(terminated).toBe(true);
        expect(localStorage.getItem('currentExamData')).toBeNull();
        expect(localStorage.getItem('currentExamId')).toBeNull();
    });
});

describe('HomePage session state on load', () => {
    it('sweeps stale per-exam localStorage keys when no session is active', async () => {
        localStorage.setItem('ckx-exam-paused:old-1', '1');
        localStorage.setItem('ckx-exam-progress:old-1', '{}');
        localStorage.setItem('unrelated-key', 'keep');
        defaultRoutes();
        renderPage();

        await waitFor(() => expect(localStorage.getItem('ckx-exam-paused:old-1')).toBeNull());
        expect(localStorage.getItem('ckx-exam-progress:old-1')).toBeNull();
        expect(localStorage.getItem('unrelated-key')).toBe('keep');
    });

    it('resumes a PREPARING session: overlay + polling + redirect when READY', async () => {
        vi.useFakeTimers();
        let statusCalls = 0;
        fetchMock.mockImplementation((url: string) => {
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(
                    jsonResponse({ id: 'exam-7', status: 'PREPARING', info: { name: 'CKS Mock 1' } })
                );
            if (url === '/facilitator/api/v1/assements/') return Promise.resolve(jsonResponse(LABS));
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(jsonResponse(CERTS));
            if (url === '/facilitator/api/v1/exams/attempts')
                return Promise.resolve(jsonResponse(ATTEMPTS));
            if (url === '/facilitator/api/v1/exams/exam-7/status') {
                statusCalls += 1;
                return Promise.resolve(
                    jsonResponse({ status: statusCalls >= 2 ? 'READY' : 'PREPARING' })
                );
            }
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await vi.waitFor(() => {
            const overlay = document.getElementById('loadingOverlay');
            expect(overlay).toBeInTheDocument();
        });
        await vi.advanceTimersByTimeAsync(1100);
        await vi.advanceTimersByTimeAsync(1100);
        await vi.advanceTimersByTimeAsync(1100);
        expect(navigate).toHaveBeenCalledWith('/exam.html?id=exam-7');
    });

    it('shows View Result only for EVALUATED sessions and routes through localStorage', async () => {
        defaultRoutes(jsonResponse({ id: 'exam-3', status: 'EVALUATED', info: { name: 'CKA Mock 1' } }));
        const user = userEvent.setup();
        renderPage();

        await waitFor(() =>
            expect(document.getElementById('viewPastResultsBtn')).toBeInTheDocument()
        );
        expect(localStorage.getItem('currentExamData')).toContain('exam-3');
        await user.click(document.getElementById('viewPastResultsBtn') as HTMLElement);
        expect(navigate).toHaveBeenCalledWith('/results?id=exam-3');
    });

    it('keeps the viewPastResultsBtn id unique when the mobile menu is open', async () => {
        defaultRoutes(jsonResponse({ id: 'exam-3', status: 'EVALUATED', info: { name: 'CKA Mock 1' } }));
        const user = userEvent.setup();
        renderPage();

        await waitFor(() =>
            expect(document.getElementById('viewPastResultsBtn')).toBeInTheDocument()
        );
        await user.click(screen.getByRole('button', { name: 'Toggle navigation' }));
        // Mobile panel shows its own copy of the link, but the id stays unique
        expect(document.querySelectorAll('#viewPastResultsBtn')).toHaveLength(1);
        expect(screen.getAllByText('View Result').length).toBeGreaterThanOrEqual(2);
    });

    it('hides View Result for READY sessions', async () => {
        defaultRoutes(jsonResponse({ id: 'exam-5', status: 'READY', info: { name: 'CKA Mock 1' } }));
        renderPage();
        await waitFor(() => expect(document.getElementById('attemptsContent')).toBeInTheDocument());
        expect(document.getElementById('viewPastResultsBtn')).not.toBeInTheDocument();
    });
});
