import { useQuery } from '@tanstack/react-query';
import { AppShell } from '@/components/shell/AppShell';
import { Card, CardContent } from '@/components/ui/card';
import { Chip } from '@/components/ui/chip';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow
} from '@/components/ui/table';
import { API_BASE } from '@/lib/api';
import { usePageTitle } from '@/lib/use-page-title';
import { cn } from '@/lib/utils';

// React port of analytics.html + js/analytics.js. Every number comes from
// /facilitator/api/v1/analytics — nothing is simulated, and missing
// evidence stays an explicit "insufficient evidence" state. The SVG trend
// chart is the legacy chart re-rendered as a component with theme-aware
// token colors (validated per-surface series palette from tokens.css), a
// native-title tooltip per point, a dashed pass threshold, a direct label
// on the latest score, and the same <details> data-table fallback for
// screen readers and keyboard users.

interface TrendEntry {
    completedAt: string;
    labName: string;
    percentageScore: number;
}

interface DomainMastery {
    totalAttempts: number;
    attemptsWithDomainData: number;
    domains: {
        domainName: string;
        weightPercent?: number | null;
        masteryPercent: number | null;
        earned?: number;
        possible?: number;
    }[];
}

interface Readiness {
    status: string;
    detail?: string;
    rules?: { label: string; detail: string; satisfied: boolean | null }[];
}

interface Certification {
    code: string;
    displayName: string;
    attemptCount: number;
    latestPercentage?: number;
    bestPercentage?: number;
    passThresholdPercent?: number | null;
    blueprintVersion?: string | null;
    scoreTrend: TrendEntry[];
    domainMastery: DomainMastery;
    readiness: Readiness;
}

interface Analytics {
    totalAttempts: number;
    uncategorizedAttempts: number;
    certifications: Certification[];
}

function formatDate(isoString: string) {
    const date = new Date(isoString);
    return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString();
}

// Legacy renderTrendSvg ported 1:1; colors resolve through CSS variables so
// the same chart is valid on both theme surfaces.
export function TrendChart({
    trend,
    threshold
}: {
    trend: TrendEntry[];
    threshold?: number | null | undefined;
}) {
    if (trend.length < 2) {
        return null;
    }

    const width = 720;
    const height = 220;
    const padding = { top: 18, right: 46, bottom: 30, left: 36 };
    const plotWidth = width - padding.left - padding.right;
    const plotHeight = height - padding.top - padding.bottom;

    const xFor = (index: number) => padding.left + (index / (trend.length - 1)) * plotWidth;
    const yFor = (score: number) => padding.top + (1 - score / 100) * plotHeight;

    const points = trend
        .map((entry, index) => `${xFor(index).toFixed(1)},${yFor(entry.percentageScore).toFixed(1)}`)
        .join(' ');

    const series = 'var(--ckx-series-1)';
    const grid = 'var(--ckx-border)';
    const axisInk = 'var(--ckx-ink-muted)';
    const thresholdColor = 'var(--ckx-warn)';
    const surface = 'var(--ckx-surface)';
    const ink = 'var(--ckx-ink)';

    // Guarded above: trend has ≥ 2 entries here.
    const first = trend[0]!;
    const last = trend[trend.length - 1]!;

    return (
        <div className="max-w-[720px]">
            <svg
                viewBox={`0 0 ${width} ${height}`}
                role="img"
                aria-label="Score trend chart"
                style={{ width: '100%', height: 'auto', display: 'block' }}
            >
                {[0, 25, 50, 75, 100].map((score) => (
                    <g key={score}>
                        <line
                            x1={padding.left}
                            y1={yFor(score)}
                            x2={width - padding.right}
                            y2={yFor(score)}
                            style={{ stroke: grid }}
                            strokeWidth={1}
                        />
                        <text
                            x={padding.left - 8}
                            y={yFor(score)}
                            textAnchor="end"
                            dominantBaseline="middle"
                            fontSize={11}
                            style={{ fill: axisInk }}
                        >
                            {score}
                        </text>
                    </g>
                ))}
                {typeof threshold === 'number' ? (
                    <g>
                        <line
                            x1={padding.left}
                            y1={yFor(threshold)}
                            x2={width - padding.right}
                            y2={yFor(threshold)}
                            style={{ stroke: thresholdColor }}
                            strokeWidth={1}
                            strokeDasharray="4 4"
                            opacity={0.75}
                        />
                        <text
                            x={width - padding.right}
                            y={yFor(threshold) - 6}
                            textAnchor="end"
                            fontSize={11}
                            style={{ fill: thresholdColor }}
                        >
                            pass {threshold}%
                        </text>
                    </g>
                ) : null}
                <polyline
                    points={points}
                    fill="none"
                    style={{ stroke: series }}
                    strokeWidth={2}
                    strokeLinejoin="round"
                    strokeLinecap="round"
                />
                {trend.map((entry, index) => (
                    <circle
                        key={index}
                        cx={xFor(index)}
                        cy={yFor(entry.percentageScore)}
                        r={3.5}
                        style={{ fill: series, stroke: surface }}
                        strokeWidth={2}
                    >
                        <title>
                            {`${formatDate(entry.completedAt)} — ${entry.labName}: ${entry.percentageScore}%`}
                        </title>
                    </circle>
                ))}
                <text
                    x={width - padding.right + 8}
                    y={yFor(last.percentageScore)}
                    dominantBaseline="middle"
                    fontSize={12}
                    fontWeight={600}
                    style={{ fill: ink }}
                >
                    {last.percentageScore}%
                </text>
                <text x={padding.left} y={height - 8} fontSize={11} style={{ fill: axisInk }}>
                    {formatDate(first.completedAt)}
                </text>
                <text
                    x={width - padding.right}
                    y={height - 8}
                    textAnchor="end"
                    fontSize={11}
                    style={{ fill: axisInk }}
                >
                    {formatDate(last.completedAt)}
                </text>
            </svg>
        </div>
    );
}

function TrendTable({ trend }: { trend: TrendEntry[] }) {
    if (!trend.length) {
        return null;
    }
    return (
        <details className="mt-3">
            <summary className="cursor-pointer text-sm text-ink-secondary">
                Score data as table
            </summary>
            <Table>
                <TableHeader>
                    <TableRow>
                        <TableHead>Date</TableHead>
                        <TableHead>Lab</TableHead>
                        <TableHead className="text-right">Score</TableHead>
                    </TableRow>
                </TableHeader>
                <TableBody>
                    {trend.map((entry, index) => (
                        <TableRow key={index}>
                            <TableCell>{formatDate(entry.completedAt)}</TableCell>
                            <TableCell>{entry.labName}</TableCell>
                            <TableCell className="text-right">{entry.percentageScore}%</TableCell>
                        </TableRow>
                    ))}
                </TableBody>
            </Table>
        </details>
    );
}

function MasterySection({ domainMastery }: { domainMastery: DomainMastery }) {
    if (!domainMastery.domains.length) {
        return <p className="text-ink-muted">No blueprint domains configured.</p>;
    }
    return (
        <>
            {domainMastery.attemptsWithDomainData < domainMastery.totalAttempts ? (
                <p className="text-xs text-ink-muted">
                    Domain data available for {domainMastery.attemptsWithDomainData} of{' '}
                    {domainMastery.totalAttempts} attempts (older attempts predate domain tracking).
                </p>
            ) : null}
            <div className="mt-2 flex flex-col gap-2">
                {domainMastery.domains.map((domain) => (
                    <div
                        key={domain.domainName}
                        className="grid grid-cols-1 items-center gap-2 sm:grid-cols-[minmax(12rem,1.2fr)_1fr_minmax(7rem,auto)]"
                    >
                        <div className="text-sm">
                            {domain.domainName}
                            {domain.weightPercent != null ? ` (${domain.weightPercent}% of exam)` : ''}
                        </div>
                        {domain.masteryPercent === null ? (
                            <>
                                <div
                                    aria-hidden
                                    className="h-2.5 rounded-full bg-surface-soft"
                                />
                                <div className="text-sm text-ink-muted">not practiced</div>
                            </>
                        ) : (
                            <>
                                <div className="h-2.5 overflow-hidden rounded-full bg-surface-soft">
                                    <div
                                        role="img"
                                        aria-label={`${domain.domainName} mastery ${domain.masteryPercent} percent`}
                                        className={cn(
                                            'h-full rounded-full',
                                            domain.masteryPercent < 50 ? 'bg-series-low' : 'bg-series-1'
                                        )}
                                        style={{ width: `${domain.masteryPercent}%` }}
                                    />
                                </div>
                                <div className="text-sm">
                                    {domain.masteryPercent}%
                                    <span className="text-xs text-ink-muted">
                                        {' '}
                                        ({domain.earned}/{domain.possible})
                                    </span>
                                </div>
                            </>
                        )}
                    </div>
                ))}
            </div>
        </>
    );
}

function ReadinessSection({ readiness }: { readiness: Readiness }) {
    if (readiness.status === 'insufficient-evidence') {
        return (
            <div className="rounded-ckx border border-dashed border-line-strong bg-surface-soft p-4 text-ink-muted">
                Insufficient evidence: {readiness.detail}
            </div>
        );
    }
    return (
        <>
            <p className="mb-2 text-sm">
                Readiness is the list of checks below — CK-X does not reduce it to a single number.
            </p>
            <ul className="flex flex-col gap-2">
                {(readiness.rules ?? []).map((rule, index) => (
                    <li key={index} className="flex flex-wrap items-center gap-2 text-sm">
                        {rule.satisfied === true ? (
                            <Chip tone="good">MET</Chip>
                        ) : rule.satisfied === false ? (
                            <Chip tone="bad">NOT MET</Chip>
                        ) : (
                            <Chip tone="muted">NO EVIDENCE</Chip>
                        )}
                        <span>
                            {rule.label} — <span className="text-ink-muted">{rule.detail}</span>
                        </span>
                    </li>
                ))}
            </ul>
        </>
    );
}

function CertificationCard({ cert }: { cert: Certification }) {
    const hasAttempts = cert.attemptCount > 0;
    const summary = hasAttempts
        ? `${cert.attemptCount} attempt(s) · latest ${cert.latestPercentage}% · best ${cert.bestPercentage}%` +
          (cert.passThresholdPercent ? ` · pass threshold ${cert.passThresholdPercent}%` : '')
        : 'No attempts stored for this certification yet.';

    return (
        <Card aria-label={`${cert.code} analytics`}>
            <CardContent>
                <h2 className="text-lg font-semibold">
                    {cert.code} — {cert.displayName}
                </h2>
                <p className="text-sm text-ink-muted">
                    {summary}
                    {cert.blueprintVersion ? ` · curriculum ${cert.blueprintVersion}` : ''}
                </p>
                {hasAttempts ? (
                    <>
                        <h3 className="mt-4 text-sm font-semibold">Score trend</h3>
                        {cert.scoreTrend.length >= 2 ? (
                            <TrendChart trend={cert.scoreTrend} threshold={cert.passThresholdPercent} />
                        ) : (
                            <p className="text-sm text-ink-muted">
                                One attempt so far — a trend needs at least two.
                            </p>
                        )}
                        <TrendTable trend={cert.scoreTrend} />
                        <h3 className="mb-2 mt-5 text-sm font-semibold">Domain mastery</h3>
                        <MasterySection domainMastery={cert.domainMastery} />
                        <h3 className="mb-2 mt-5 text-sm font-semibold">Readiness evidence</h3>
                        <ReadinessSection readiness={cert.readiness} />
                    </>
                ) : (
                    <div className="mt-4 rounded-ckx border border-dashed border-line-strong bg-surface-soft p-4 text-ink-muted">
                        Take a {cert.code} exam to start collecting evidence.
                    </div>
                )}
            </CardContent>
        </Card>
    );
}

async function fetchAnalytics(): Promise<Analytics> {
    const response = await fetch(`${API_BASE}/analytics`);
    if (!response.ok) {
        throw new Error('Status ' + response.status);
    }
    const payload = await response.json();
    return payload.data as Analytics;
}

export function AnalyticsPage() {
    usePageTitle('Analytics | CK-X');
    const query = useQuery({ queryKey: ['analytics'], queryFn: fetchAnalytics });
    const analytics = query.data;

    const withAttempts = analytics?.certifications.filter((cert) => cert.attemptCount > 0) ?? [];
    const withoutAttempts = analytics?.certifications.filter((cert) => cert.attemptCount === 0) ?? [];

    return (
        <AppShell activeHref="/analytics.html">
            <header className="mb-8">
                <h1 className="text-3xl font-bold tracking-tight">Analytics</h1>
                <p className="mt-2 text-ink-secondary">
                    Everything below is computed from your stored attempts — nothing is simulated. When
                    there is not enough evidence, CK-X says so instead of inventing a score.
                </p>
            </header>

            <div
                id="analyticsStatus"
                role="status"
                className={cn('min-h-5 text-sm', query.isError ? 'text-bad' : 'text-ink-muted')}
            >
                {query.isLoading
                    ? 'Loading analytics…'
                    : query.isError
                      ? 'Failed to load analytics. Is the facilitator running?'
                      : ''}
            </div>

            <div id="analyticsContent" className="flex flex-col gap-5">
                {analytics ? (
                    !analytics.totalAttempts ? (
                        <div className="rounded-ckx border border-dashed border-line-strong bg-surface-soft p-6 text-center text-ink-muted">
                            No attempts stored yet. Complete an exam and analytics will appear here.
                        </div>
                    ) : (
                        <>
                            {analytics.uncategorizedAttempts > 0 ? (
                                <p className="text-xs text-ink-muted">
                                    {analytics.uncategorizedAttempts} attempt(s) belong to
                                    non-certification categories (e.g. Docker practice) and are not shown
                                    here.
                                </p>
                            ) : null}
                            {withAttempts.map((cert) => (
                                <CertificationCard key={cert.code} cert={cert} />
                            ))}
                            {withoutAttempts.length ? (
                                <Card>
                                    <CardContent>
                                        <h2 className="text-lg font-semibold">Not started</h2>
                                        <p className="mt-1 text-sm text-ink-muted">
                                            {withoutAttempts.map((cert) => cert.code).join(' · ')}
                                        </p>
                                    </CardContent>
                                </Card>
                            ) : null}
                        </>
                    )
                ) : null}
            </div>
        </AppShell>
    );
}

export default AnalyticsPage;
