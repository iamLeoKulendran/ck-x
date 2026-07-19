import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { getQueryParam, navigate, openInNewTab } from '@/lib/navigation';
import { ResultsPage } from './ResultsPage';

// All network I/O mocked; terminate/evaluate/mistake POSTs only ever see
// fixture exam ids.

vi.mock('@/lib/navigation', () => ({
    navigate: vi.fn(),
    openInNewTab: vi.fn(),
    getQueryParam: vi.fn(() => 'exam-1')
}));

const RESULT = {
    data: {
        examId: 'exam-1',
        completedAt: '2026-07-10T10:00:00.000Z',
        totalScore: 63,
        totalPossibleScore: 100,
        rank: 'medium',
        evaluationResults: [
            {
                id: '2',
                concepts: ['RBAC'],
                verificationResults: [
                    { id: '1', description: 'Role exists', validAnswer: true, score: 4, weightage: 4 },
                    { id: '2', description: 'Binding correct', validAnswer: false, score: 0, weightage: 3 }
                ]
            },
            {
                id: '1',
                concepts: [],
                verificationResults: [
                    { id: '1', description: 'Pod running', validAnswer: true, score: 5, weightage: 5 }
                ]
            }
        ]
    }
};

function jsonResponse(body: unknown, ok = true, status = ok ? 200 : 500) {
    return { ok, status, json: () => Promise.resolve(body) } as Response;
}

const fetchMock = vi.fn();

function renderPage() {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    return render(
        <QueryClientProvider client={client}>
            <ThemeProvider>
                <ToastProvider>
                    <ResultsPage />
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}

beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
    fetchMock.mockReset();
    vi.mocked(getQueryParam).mockReturnValue('exam-1');
});

afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
});

function happyRoutes() {
    fetchMock.mockImplementation((url: string) => {
        if (url === '/facilitator/api/v1/exams/exam-1/result')
            return Promise.resolve(jsonResponse(RESULT));
        if (url === '/facilitator/api/v1/certifications')
            return Promise.resolve(jsonResponse({ certifications: [] }));
        if (url === '/facilitator/api/v1/exams/current')
            return Promise.resolve(jsonResponse({}, false, 404));
        return Promise.reject(new Error(`Unexpected fetch: ${url}`));
    });
}

describe('ResultsPage', () => {
    it('shows the explicit error when no exam id is provided', async () => {
        vi.mocked(getQueryParam).mockReturnValue(null);
        renderPage();
        await waitFor(() =>
            expect(screen.getByText(/No exam ID provided/)).toBeInTheDocument()
        );
    });

    it('renders scores, rank, and questions sorted numerically', async () => {
        happyRoutes();
        renderPage();

        await waitFor(() => expect(screen.getByText('Exam ID: exam-1')).toBeInTheDocument());
        expect(document.getElementById('totalScore')?.textContent).toBe('63');
        expect(document.getElementById('totalPossibleScore')?.textContent).toBe('100');
        expect(screen.getByText('Medium Score')).toBeInTheDocument();
        const titles = Array.from(document.querySelectorAll('.question-title')).map(
            (node) => node.textContent
        );
        expect(titles).toEqual(['Question 1', 'Question 2']);
        // Per-question score sums from verification steps
        expect(screen.getByText('4 of 7')).toBeInTheDocument();
        expect(screen.getByText('5 of 5')).toBeInTheDocument();
        expect(screen.getByText('Binding correct')).toBeInTheDocument();
    });

    it('polls status on 404 result and renders once EVALUATED', async () => {
        let resultCalls = 0;
        let statusCalls = 0;
        fetchMock.mockImplementation((url: string) => {
            if (url === '/facilitator/api/v1/exams/exam-1/result') {
                resultCalls += 1;
                return Promise.resolve(
                    resultCalls === 1 ? jsonResponse({}, false, 404) : jsonResponse(RESULT)
                );
            }
            if (url === '/facilitator/api/v1/exams/exam-1/status') {
                statusCalls += 1;
                return Promise.resolve(
                    jsonResponse({ status: statusCalls >= 2 ? 'EVALUATED' : 'EVALUATING' })
                );
            }
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(jsonResponse({ certifications: [] }));
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(jsonResponse({}, false, 404));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await waitFor(
            () => expect(screen.getByText('Exam ID: exam-1')).toBeInTheDocument(),
            { timeout: 8000 }
        );
        expect(statusCalls).toBeGreaterThanOrEqual(2);
    }, 10000);

    it('shows the failure message when evaluation failed', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (url === '/facilitator/api/v1/exams/exam-1/result')
                return Promise.resolve(jsonResponse({}, false, 404));
            if (url === '/facilitator/api/v1/exams/exam-1/status')
                return Promise.resolve(jsonResponse({ status: 'EVALUATION_FAILED' }));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();
        await waitFor(() =>
            expect(screen.getByText(/Exam evaluation failed/)).toBeInTheDocument()
        );
    });

    it('re-evaluate POSTs then polls to fresh results', async () => {
        let evaluated = false;
        let statusAfterEvaluate = 0;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === '/facilitator/api/v1/exams/exam-1/result')
                return Promise.resolve(jsonResponse(RESULT));
            if (url === '/facilitator/api/v1/exams/exam-1/evaluate' && options?.method === 'POST') {
                evaluated = true;
                return Promise.resolve(jsonResponse({}));
            }
            if (url === '/facilitator/api/v1/exams/exam-1/status') {
                statusAfterEvaluate += 1;
                return Promise.resolve(jsonResponse({ status: 'EVALUATED' }));
            }
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(jsonResponse({ certifications: [] }));
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(jsonResponse({}, false, 404));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Exam ID: exam-1')).toBeInTheDocument());
        await user.click(document.getElementById('reEvaluateBtn') as HTMLElement);
        await waitFor(() => expect(evaluated).toBe(true));
        await waitFor(
            () => {
                expect(statusAfterEvaluate).toBeGreaterThanOrEqual(1);
                expect(screen.getByText('Exam ID: exam-1')).toBeInTheDocument();
            },
            { timeout: 8000 }
        );
    }, 10000);

    it('terminate asks for confirmation, POSTs, and navigates home', async () => {
        let terminated = false;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === '/facilitator/api/v1/exams/exam-1/result')
                return Promise.resolve(jsonResponse(RESULT));
            if (url === '/facilitator/api/v1/exams/exam-1/terminate' && options?.method === 'POST') {
                terminated = true;
                return Promise.resolve(jsonResponse({}));
            }
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(jsonResponse({ certifications: [] }));
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(jsonResponse({}, false, 404));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Exam ID: exam-1')).toBeInTheDocument());
        await user.click(document.getElementById('terminateBtn') as HTMLElement);
        // Modal appears; cancel first
        await waitFor(() => expect(document.getElementById('terminateModal')).toBeInTheDocument());
        await user.click(document.getElementById('cancelTerminateBtn') as HTMLElement);
        expect(document.getElementById('terminateModal')).not.toBeInTheDocument();
        expect(terminated).toBe(false);

        await user.click(document.getElementById('terminateBtn') as HTMLElement);
        await user.click(document.getElementById('confirmTerminateBtn') as HTMLElement);
        await waitFor(() => expect(terminated).toBe(true));
        expect(navigate).toHaveBeenCalledWith('/');
    });

    it('opens current exam and answers in new tabs', async () => {
        happyRoutes();
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Exam ID: exam-1')).toBeInTheDocument());
        await user.click(document.getElementById('currentExamBtn') as HTMLElement);
        expect(openInNewTab).toHaveBeenCalledWith('/exam.html?id=exam-1');
        await user.click(document.getElementById('viewAnswersBtn') as HTMLElement);
        expect(openInNewTab).toHaveBeenCalledWith('/answers.html?id=exam-1');
    });

    it('logs a mistake for a failed question with the attempt context', async () => {
        let mistakeBody: Record<string, unknown> | null = null;
        fetchMock.mockImplementation((url: string, options?: RequestInit) => {
            if (url === '/facilitator/api/v1/exams/exam-1/result')
                return Promise.resolve(jsonResponse(RESULT));
            if (url === '/facilitator/api/v1/exams/attempts')
                return Promise.resolve(
                    jsonResponse({
                        data: {
                            attempts: [
                                {
                                    attemptId: 'a-9',
                                    examSessionId: 'exam-1',
                                    labId: 'cka-001',
                                    labName: 'CKA Mock 1',
                                    certificationCode: 'CKA'
                                }
                            ]
                        }
                    })
                );
            if (url === '/facilitator/api/v1/mistakes' && options?.method === 'POST') {
                mistakeBody = JSON.parse(String(options.body)) as Record<string, unknown>;
                return Promise.resolve(jsonResponse({ data: { duplicate: false } }));
            }
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(jsonResponse({ certifications: [] }));
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(jsonResponse({}, false, 404));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() => expect(screen.getByText('Exam ID: exam-1')).toBeInTheDocument());
        // Only the question with a failed step gets the control
        const buttons = screen.getAllByRole('button', { name: 'Log mistake for review' });
        expect(buttons).toHaveLength(1);
        await user.click(buttons[0]!);

        await waitFor(() => expect(mistakeBody).not.toBeNull());
        expect(mistakeBody!.summary).toBe('Question 2: Binding correct');
        const source = mistakeBody!.source as Record<string, unknown>;
        expect(source.attemptId).toBe('a-9');
        expect(source.labId).toBe('cka-001');
        expect(source.certificationCode).toBe('CKA');
        expect(source.questionId).toBe('2');
        await waitFor(() =>
            expect(
                screen.getByText('Logged. Categorize it on the Mistakes page.')
            ).toBeInTheDocument()
        );
    });

    it('sets the legacy document title', async () => {
        happyRoutes();
        renderPage();
        await waitFor(() => expect(document.title).toBe('Results | CK-X'));
    });
});

describe('ResultsPage pass threshold', () => {
    it('annotates the score against the certification threshold when the session matches', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (url === '/facilitator/api/v1/exams/exam-1/result')
                return Promise.resolve(jsonResponse(RESULT));
            if (url === '/facilitator/api/v1/certifications')
                return Promise.resolve(
                    jsonResponse({
                        certifications: [
                            {
                                code: 'CKA',
                                passThresholdPercent: 66,
                                blueprint: { version: 'v1.32' }
                            }
                        ]
                    })
                );
            if (url === '/facilitator/api/v1/exams/current')
                return Promise.resolve(
                    jsonResponse({ id: 'exam-1', status: 'EVALUATED', info: { category: 'CKA' } })
                );
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await waitFor(() =>
            expect(document.getElementById('passThresholdInfo')).toBeInTheDocument()
        );
        const info = document.getElementById('passThresholdInfo')!;
        expect(within(info as HTMLElement).getByText('BELOW THRESHOLD')).toBeInTheDocument();
        expect(info.textContent).toContain('CKA pass threshold 66%');
        expect(info.textContent).toContain('your score 63.0%');
    });
});
