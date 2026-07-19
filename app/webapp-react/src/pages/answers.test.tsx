import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { getQueryParam, navigate } from '@/lib/navigation';
import { AnswersPage } from './AnswersPage';

// Read-only page; only GET /answers is mocked.

vi.mock('@/lib/navigation', () => ({
    navigate: vi.fn(),
    openInNewTab: vi.fn(),
    getQueryParam: vi.fn(() => 'exam-1')
}));

const MARKDOWN = [
    '# Question 1',
    '',
    'Create the pod:',
    '',
    '```bash',
    'kubectl run web --image=nginx',
    '```'
].join('\n');

function textResponse(body: string, ok = true, status = 200) {
    return {
        ok,
        status,
        text: () => Promise.resolve(body),
        json: () => Promise.resolve({})
    } as unknown as Response;
}

const fetchMock = vi.fn();

function renderPage() {
    return render(
        <ThemeProvider>
            <AnswersPage />
        </ThemeProvider>
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

describe('AnswersPage', () => {
    it('renders the markdown answers with highlighted code blocks', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (url === '/facilitator/api/v1/exams/exam-1/answers')
                return Promise.resolve(textResponse(MARKDOWN));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await waitFor(() =>
            expect(screen.getByRole('heading', { name: 'Question 1' })).toBeInTheDocument()
        );
        expect(screen.getByText('Exam ID: exam-1')).toBeInTheDocument();
        const code = document.querySelector('pre code');
        expect(code?.textContent).toContain('kubectl run web');
        // highlight.js marks processed blocks with the hljs class
        await waitFor(() => expect(code?.className).toContain('hljs'));
    });

    it('shows the locked message on 403', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(textResponse('', false, 403)));
        renderPage();
        await waitFor(() =>
            expect(screen.getByText(/Solutions are locked/)).toBeInTheDocument()
        );
    });

    it('shows an error with retry on failure, and retry reloads', async () => {
        let calls = 0;
        fetchMock.mockImplementation(() => {
            calls += 1;
            return Promise.resolve(
                calls === 1 ? textResponse('', false, 500) : textResponse(MARKDOWN)
            );
        });
        const user = userEvent.setup();
        renderPage();

        await waitFor(() =>
            expect(screen.getByText(/Failed to load answers: HTTP error! Status: 500/)).toBeInTheDocument()
        );
        await user.click(document.getElementById('retryButton') as HTMLElement);
        await waitFor(() =>
            expect(screen.getByRole('heading', { name: 'Question 1' })).toBeInTheDocument()
        );
    });

    it('shows the explicit error when no exam id is provided', async () => {
        vi.mocked(getQueryParam).mockReturnValue(null);
        renderPage();
        await waitFor(() =>
            expect(
                screen.getByText(/No exam ID provided. Please return to the results page./)
            ).toBeInTheDocument()
        );
    });

    it('back to results navigates with the exam id', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(textResponse(MARKDOWN)));
        const user = userEvent.setup();
        renderPage();

        await waitFor(() =>
            expect(screen.getByRole('heading', { name: 'Question 1' })).toBeInTheDocument()
        );
        await user.click(document.getElementById('backToResultsBtn') as HTMLElement);
        expect(navigate).toHaveBeenCalledWith('/results.html?id=exam-1');
    });

    it('sets the legacy document title', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(textResponse(MARKDOWN)));
        renderPage();
        await waitFor(() => expect(document.title).toBe('Answers | CK-X'));
    });
});
