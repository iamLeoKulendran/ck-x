import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { AnalyticsPage, TrendChart } from './AnalyticsPage';

// Analytics is strictly read-only: one GET, fully mocked here.

const ANALYTICS_URL = '/facilitator/api/v1/analytics';

const POPULATED = {
    totalAttempts: 5,
    uncategorizedAttempts: 1,
    certifications: [
        {
            code: 'CKA',
            displayName: 'Certified Kubernetes Administrator',
            attemptCount: 3,
            latestPercentage: 78,
            bestPercentage: 84,
            passThresholdPercent: 66,
            blueprintVersion: '2026-v1',
            scoreTrend: [
                { completedAt: '2026-06-01T10:00:00.000Z', labName: 'CKA Mock 1', percentageScore: 61 },
                { completedAt: '2026-06-15T10:00:00.000Z', labName: 'CKA Mock 2', percentageScore: 84 },
                { completedAt: '2026-07-01T10:00:00.000Z', labName: 'CKA Mock 3', percentageScore: 78 }
            ],
            domainMastery: {
                totalAttempts: 3,
                attemptsWithDomainData: 2,
                domains: [
                    {
                        domainName: 'Troubleshooting',
                        weightPercent: 30,
                        masteryPercent: 72,
                        earned: 36,
                        possible: 50
                    },
                    {
                        domainName: 'Storage',
                        weightPercent: 10,
                        masteryPercent: 40,
                        earned: 8,
                        possible: 20
                    },
                    { domainName: 'Workloads', weightPercent: 15, masteryPercent: null }
                ]
            },
            readiness: {
                status: 'evaluated',
                rules: [
                    { label: 'Two passes in a row', detail: 'latest two ≥ 66%', satisfied: true },
                    { label: 'Every domain practiced', detail: 'Workloads unpracticed', satisfied: false },
                    { label: 'Recent attempt', detail: 'no attempt in window', satisfied: null }
                ]
            }
        },
        {
            code: 'CKS',
            displayName: 'Certified Kubernetes Security Specialist',
            attemptCount: 1,
            latestPercentage: 55,
            bestPercentage: 55,
            passThresholdPercent: 67,
            blueprintVersion: null,
            scoreTrend: [
                { completedAt: '2026-07-02T10:00:00.000Z', labName: 'CKS Mock 1', percentageScore: 55 }
            ],
            domainMastery: { totalAttempts: 1, attemptsWithDomainData: 1, domains: [] },
            readiness: { status: 'insufficient-evidence', detail: 'need at least 2 attempts' }
        },
        {
            code: 'KCNA',
            displayName: 'Kubernetes and Cloud Native Associate',
            attemptCount: 0,
            scoreTrend: [],
            domainMastery: { totalAttempts: 0, attemptsWithDomainData: 0, domains: [] },
            readiness: { status: 'insufficient-evidence', detail: 'no attempts' }
        }
    ]
};

function jsonResponse(body: unknown, ok = true, status = ok ? 200 : 500) {
    return { ok, status, json: () => Promise.resolve(body) } as Response;
}

function renderPage() {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    return render(
        <QueryClientProvider client={client}>
            <ThemeProvider>
                <ToastProvider>
                    <AnalyticsPage />
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}

const fetchMock = vi.fn();

beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
    fetchMock.mockReset();
});

afterEach(() => {
    vi.unstubAllGlobals();
});

describe('AnalyticsPage', () => {
    it('renders real API data: summaries, chart, mastery, readiness — no invented numbers', async () => {
        fetchMock.mockImplementation((url: string) => {
            if (url === ANALYTICS_URL) return Promise.resolve(jsonResponse({ data: POPULATED }));
            return Promise.reject(new Error(`Unexpected fetch: ${url}`));
        });
        renderPage();

        await waitFor(() =>
            expect(
                screen.getByText('CKA — Certified Kubernetes Administrator')
            ).toBeInTheDocument()
        );
        expect(
            screen.getByText('3 attempt(s) · latest 78% · best 84% · pass threshold 66% · curriculum 2026-v1')
        ).toBeInTheDocument();

        // Chart: real SVG with accessible name, one point per attempt, threshold line
        const chart = screen.getByRole('img', { name: 'Score trend chart' });
        expect(chart.querySelectorAll('circle')).toHaveLength(3);
        expect(chart.textContent).toContain('pass 66%');
        expect(chart.textContent).toContain('78%'); // direct label on latest point

        // Accessible data table fallback with the same real values — one per
        // cert with a trend (legacy renders the table even for one attempt)
        expect(screen.getAllByText('Score data as table')).toHaveLength(2);
        expect(screen.getByText('CKA Mock 2')).toBeInTheDocument();

        // Mastery bars: values, weights, aria labels, partial-data note, not-practiced
        expect(
            screen.getByRole('img', { name: 'Troubleshooting mastery 72 percent' })
        ).toBeInTheDocument();
        expect(screen.getByText(/Domain data available for 2 of 3 attempts/)).toBeInTheDocument();
        expect(screen.getByText('not practiced')).toBeInTheDocument();
        expect(screen.getByText('Troubleshooting (30% of exam)')).toBeInTheDocument();

        // Readiness chips reflect the three satisfied states
        expect(screen.getByText('MET')).toBeInTheDocument();
        expect(screen.getByText('NOT MET')).toBeInTheDocument();
        expect(screen.getByText('NO EVIDENCE')).toBeInTheDocument();

        // Uncategorized note and not-started section
        expect(screen.getByText(/1 attempt\(s\) belong to non-certification categories/)).toBeInTheDocument();
        expect(screen.getByText('Not started')).toBeInTheDocument();
        expect(screen.getByText('KCNA')).toBeInTheDocument();
    });

    it('shows the single-attempt message instead of a trend chart', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(jsonResponse({ data: POPULATED })));
        renderPage();

        await waitFor(() =>
            expect(
                screen.getByText('One attempt so far — a trend needs at least two.')
            ).toBeInTheDocument()
        );
        // Only the CKA chart exists — CKS with one attempt renders none
        expect(screen.getAllByRole('img', { name: 'Score trend chart' })).toHaveLength(1);
    });

    it('renders the insufficient-evidence readiness state verbatim', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(jsonResponse({ data: POPULATED })));
        renderPage();
        await waitFor(() =>
            expect(
                screen.getByText('Insufficient evidence: need at least 2 attempts')
            ).toBeInTheDocument()
        );
    });

    it('renders the empty state when no attempts are stored', async () => {
        fetchMock.mockImplementation(() =>
            Promise.resolve(
                jsonResponse({ data: { totalAttempts: 0, uncategorizedAttempts: 0, certifications: [] } })
            )
        );
        renderPage();
        await waitFor(() =>
            expect(
                screen.getByText('No attempts stored yet. Complete an exam and analytics will appear here.')
            ).toBeInTheDocument()
        );
    });

    it('shows the legacy error message when the API fails', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(jsonResponse({}, false, 500)));
        renderPage();
        await waitFor(() =>
            expect(document.getElementById('analyticsStatus')).toHaveTextContent(
                'Failed to load analytics. Is the facilitator running?'
            )
        );
        expect(document.getElementById('analyticsContent')!.textContent).toBe('');
    });

    it('shows the no-attempts card for a certification without attempts', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(jsonResponse({ data: POPULATED })));
        renderPage();
        // KCNA appears only in Not started (attemptCount 0 certs are split out)
        await waitFor(() => expect(screen.getByText('Not started')).toBeInTheDocument());
        expect(
            screen.queryByText('KCNA — Kubernetes and Cloud Native Associate')
        ).not.toBeInTheDocument();
    });
});

describe('TrendChart', () => {
    it('returns nothing for fewer than two points', () => {
        const { container } = render(
            <TrendChart
                trend={[{ completedAt: '2026-07-01', labName: 'Solo', percentageScore: 50 }]}
                threshold={66}
            />
        );
        expect(container.innerHTML).toBe('');
    });

    it('omits the threshold line when no threshold exists', () => {
        render(
            <TrendChart
                trend={[
                    { completedAt: '2026-06-01', labName: 'A', percentageScore: 40 },
                    { completedAt: '2026-07-01', labName: 'B', percentageScore: 60 }
                ]}
                threshold={null}
            />
        );
        const chart = screen.getByRole('img', { name: 'Score trend chart' });
        expect(chart.textContent).not.toContain('pass');
    });

    it('every point carries a native tooltip with date, lab, and score', () => {
        render(
            <TrendChart
                trend={[
                    { completedAt: '2026-06-01T10:00:00.000Z', labName: 'A', percentageScore: 40 },
                    { completedAt: '2026-07-01T10:00:00.000Z', labName: 'B', percentageScore: 60 }
                ]}
                threshold={66}
            />
        );
        const titles = Array.from(
            screen.getByRole('img', { name: 'Score trend chart' }).querySelectorAll('circle > title')
        ).map((node) => node.textContent);
        expect(titles).toHaveLength(2);
        expect(titles[0]).toContain('A: 40%');
        expect(titles[1]).toContain('B: 60%');
    });

    it('sets the legacy document title', async () => {
        fetchMock.mockImplementation(() => Promise.resolve(jsonResponse({ data: POPULATED })));
        renderPage();
        await waitFor(() => expect(document.title).toBe('Analytics | CK-X'));
    });
});
