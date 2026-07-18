document.addEventListener('DOMContentLoaded', function() {
    const statusElement = document.getElementById('analyticsStatus');
    const contentElement = document.getElementById('analyticsContent');
    const currentYear = document.getElementById('currentYear');

    if (currentYear) {
        currentYear.textContent = new Date().getFullYear();
    }

    const rootStyles = getComputedStyle(document.documentElement);
    const cssVar = (name, fallback) => (rootStyles.getPropertyValue(name) || '').trim() || fallback;
    const TREND_COLOR = cssVar('--ckx-series-1', '#6d72f0');
    const GRID_COLOR = 'rgba(255, 255, 255, 0.08)';
    const AXIS_INK = '#8b91a8';
    const THRESHOLD_COLOR = '#fbbf24';
    const SURFACE = '#101016';

    function escapeHtml(value) {
        const div = document.createElement('div');
        div.textContent = value == null ? '' : String(value);
        return div.innerHTML;
    }

    function formatDate(isoString) {
        const date = new Date(isoString);
        return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString();
    }

    // Single-series score trend as inline SVG: recessive grid, 2px line,
    // surface-ringed points with native tooltips, dashed pass threshold, and
    // a direct label on the latest score. Rendered at a fixed max width so
    // marks never scale up into cartoon proportions.
    function renderTrendSvg(trend, threshold) {
        if (trend.length < 2) {
            return '';
        }

        const width = 720;
        const height = 220;
        const padding = { top: 18, right: 46, bottom: 30, left: 36 };
        const plotWidth = width - padding.left - padding.right;
        const plotHeight = height - padding.top - padding.bottom;

        const xFor = (index) => padding.left + (index / (trend.length - 1)) * plotWidth;
        const yFor = (score) => padding.top + (1 - score / 100) * plotHeight;

        const points = trend.map((entry, index) => `${xFor(index).toFixed(1)},${yFor(entry.percentageScore).toFixed(1)}`);

        const gridLines = [0, 25, 50, 75, 100].map((score) => {
            const y = yFor(score).toFixed(1);
            return `<line x1="${padding.left}" y1="${y}" x2="${width - padding.right}" y2="${y}" stroke="${GRID_COLOR}" stroke-width="1"/>` +
                   `<text x="${padding.left - 8}" y="${y}" text-anchor="end" dominant-baseline="middle" font-size="11" fill="${AXIS_INK}">${score}</text>`;
        }).join('');

        const firstDate = formatDate(trend[0].completedAt);
        const lastDate = formatDate(trend[trend.length - 1].completedAt);
        const xLabels =
            `<text x="${padding.left}" y="${height - 8}" font-size="11" fill="${AXIS_INK}">${escapeHtml(firstDate)}</text>` +
            `<text x="${width - padding.right}" y="${height - 8}" text-anchor="end" font-size="11" fill="${AXIS_INK}">${escapeHtml(lastDate)}</text>`;

        const thresholdLine = typeof threshold === 'number'
            ? `<line x1="${padding.left}" y1="${yFor(threshold).toFixed(1)}" x2="${width - padding.right}" y2="${yFor(threshold).toFixed(1)}"
                 stroke="${THRESHOLD_COLOR}" stroke-width="1" stroke-dasharray="4 4" opacity="0.75"/>
               <text x="${width - padding.right}" y="${(yFor(threshold) - 6).toFixed(1)}" text-anchor="end" font-size="11" fill="${THRESHOLD_COLOR}">pass ${threshold}%</text>`
            : '';

        const markers = trend.map((entry, index) => {
            const cx = xFor(index).toFixed(1);
            const cy = yFor(entry.percentageScore).toFixed(1);
            const label = `${formatDate(entry.completedAt)} — ${escapeHtml(entry.labName)}: ${entry.percentageScore}%`;
            return `<circle cx="${cx}" cy="${cy}" r="3.5" fill="${TREND_COLOR}" stroke="${SURFACE}" stroke-width="2">
                        <title>${label}</title>
                    </circle>`;
        }).join('');

        // Direct label on the latest point only (selective labeling)
        const last = trend[trend.length - 1];
        const lastY = yFor(last.percentageScore);
        const lastLabel = `<text x="${(width - padding.right + 8).toFixed(1)}" y="${lastY.toFixed(1)}"
             dominant-baseline="middle" font-size="12" font-weight="600" fill="#e6e8f2">${last.percentageScore}%</text>`;

        return `
            <div class="trend-chart">
                <svg viewBox="0 0 ${width} ${height}" role="img" aria-label="Score trend chart" style="width: 100%; height: auto; display: block;">
                    ${gridLines}
                    ${thresholdLine}
                    <polyline points="${points.join(' ')}" fill="none" stroke="${TREND_COLOR}" stroke-width="2"
                              stroke-linejoin="round" stroke-linecap="round"/>
                    ${markers}
                    ${lastLabel}
                    ${xLabels}
                </svg>
            </div>`;
    }

    function renderTrendTable(trend) {
        if (!trend.length) {
            return '';
        }
        const rows = trend.map((entry) => `
            <tr>
                <td>${escapeHtml(formatDate(entry.completedAt))}</td>
                <td>${escapeHtml(entry.labName)}</td>
                <td class="text-end">${entry.percentageScore}%</td>
            </tr>`).join('');

        return `
            <details class="mt-2">
                <summary>Score data as table</summary>
                <div class="table-responsive">
                    <table class="table table-sm tools-table mb-0">
                        <thead><tr><th>Date</th><th>Lab</th><th class="text-end">Score</th></tr></thead>
                        <tbody>${rows}</tbody>
                    </table>
                </div>
            </details>`;
    }

    function renderMastery(domainMastery) {
        if (!domainMastery.domains.length) {
            return '<p class="text-muted mb-0">No blueprint domains configured.</p>';
        }

        const note = domainMastery.attemptsWithDomainData < domainMastery.totalAttempts
            ? `<p class="text-muted"><small>Domain data available for ${domainMastery.attemptsWithDomainData} of ${domainMastery.totalAttempts} attempts (older attempts predate domain tracking).</small></p>`
            : '';

        const rows = domainMastery.domains.map((domain) => {
            const weight = domain.weightPercent != null ? ` (${domain.weightPercent}% of exam)` : '';
            if (domain.masteryPercent === null) {
                return `
                    <div class="mastery-row">
                        <div>${escapeHtml(domain.domainName)}${weight}</div>
                        <div class="mastery-track" aria-hidden="true"></div>
                        <div class="mastery-value text-muted">not practiced</div>
                    </div>`;
            }
            const lowClass = domain.masteryPercent < 50 ? ' mastery-fill--low' : '';
            return `
                <div class="mastery-row">
                    <div>${escapeHtml(domain.domainName)}${weight}</div>
                    <div class="mastery-track">
                        <div class="mastery-fill${lowClass}" style="width: ${domain.masteryPercent}%"
                             role="img" aria-label="${escapeHtml(domain.domainName)} mastery ${domain.masteryPercent} percent"></div>
                    </div>
                    <div class="mastery-value">${domain.masteryPercent}%<small class="text-muted"> (${domain.earned}/${domain.possible})</small></div>
                </div>`;
        }).join('');

        return note + rows;
    }

    function renderReadiness(readiness) {
        if (readiness.status === 'insufficient-evidence') {
            return `<div class="tools-empty">Insufficient evidence: ${escapeHtml(readiness.detail)}</div>`;
        }

        const items = readiness.rules.map((rule) => {
            let chip;
            if (rule.satisfied === true) {
                chip = '<span class="tools-chip tools-chip--ok">MET</span>';
            } else if (rule.satisfied === false) {
                chip = '<span class="tools-chip tools-chip--bad">NOT MET</span>';
            } else {
                chip = '<span class="tools-chip tools-chip--muted">NO EVIDENCE</span>';
            }
            return `<li class="mb-2">${chip} ${escapeHtml(rule.label)} — <span class="text-muted">${escapeHtml(rule.detail)}</span></li>`;
        }).join('');

        return `<p class="mb-2">Readiness is the list of checks below — CK-X does not reduce it to a single number.</p>
                <ul class="list-unstyled mb-0">${items}</ul>`;
    }

    function renderCertification(cert) {
        const hasAttempts = cert.attemptCount > 0;
        const summary = hasAttempts
            ? `${cert.attemptCount} attempt(s) · latest ${cert.latestPercentage}% · best ${cert.bestPercentage}%` +
              (cert.passThresholdPercent ? ` · pass threshold ${cert.passThresholdPercent}%` : '')
            : 'No attempts stored for this certification yet.';

        const body = hasAttempts
            ? `
                <h3 class="h6 mt-3">Score trend</h3>
                ${cert.scoreTrend.length >= 2 ? renderTrendSvg(cert.scoreTrend, cert.passThresholdPercent) : '<p class="text-muted">One attempt so far — a trend needs at least two.</p>'}
                ${renderTrendTable(cert.scoreTrend)}
                <h3 class="h6 mt-4">Domain mastery</h3>
                ${renderMastery(cert.domainMastery)}
                <h3 class="h6 mt-4">Readiness evidence</h3>
                ${renderReadiness(cert.readiness)}`
            : `<div class="tools-empty mt-3">Take a ${escapeHtml(cert.code)} exam to start collecting evidence.</div>`;

        return `
            <section class="card tools-card" aria-label="${escapeHtml(cert.code)} analytics">
                <div class="card-body">
                    <h2 class="h5 mb-1">${escapeHtml(cert.code)} — ${escapeHtml(cert.displayName)}</h2>
                    <p class="text-muted mb-0">${escapeHtml(summary)}${cert.blueprintVersion ? ` · curriculum ${escapeHtml(cert.blueprintVersion)}` : ''}</p>
                    ${body}
                </div>
            </section>`;
    }

    fetch('/facilitator/api/v1/analytics')
        .then(response => {
            if (!response.ok) {
                throw new Error('Status ' + response.status);
            }
            return response.json();
        })
        .then(payload => {
            const analytics = payload.data;
            statusElement.textContent = '';

            if (!analytics.totalAttempts) {
                contentElement.innerHTML = '<div class="tools-empty">No attempts stored yet. Complete an exam and analytics will appear here.</div>';
                return;
            }

            const withAttempts = analytics.certifications.filter((cert) => cert.attemptCount > 0);
            const withoutAttempts = analytics.certifications.filter((cert) => cert.attemptCount === 0);
            const uncategorizedNote = analytics.uncategorizedAttempts > 0
                ? `<p class="text-muted"><small>${analytics.uncategorizedAttempts} attempt(s) belong to non-certification categories (e.g. Docker practice) and are not shown here.</small></p>`
                : '';

            contentElement.innerHTML =
                uncategorizedNote +
                withAttempts.map(renderCertification).join('') +
                (withoutAttempts.length
                    ? `<section class="card tools-card"><div class="card-body">
                         <h2 class="h5">Not started</h2>
                         <p class="text-muted mb-0">${withoutAttempts.map((cert) => escapeHtml(cert.code)).join(' · ')}</p>
                       </div></section>`
                    : '');
        })
        .catch(error => {
            console.error('Failed to load analytics:', error);
            statusElement.textContent = 'Failed to load analytics. Is the facilitator running?';
            statusElement.classList.add('text-danger');
        });
});
