/**
 * Analytics Service
 *
 * Derives per-certification analytics from the persisted attempt history.
 * Everything here is recomputed from stored attempts on request — no cached
 * or synthetic values. When evidence is insufficient the response says so
 * instead of inventing a readiness number.
 */

const attemptHistoryService = require('./attemptHistoryService');
const certificationCatalog = require('../utils/certificationCatalog');

const MIN_ATTEMPTS_FOR_READINESS = 2;
const RECENT_ATTEMPT_WINDOW_DAYS = 14;
const DOMAIN_FLOOR_PERCENT = 50;

function getAttemptCertCode(attempt) {
  if (attempt.certificationCode) {
    return attempt.certificationCode;
  }
  const certification = certificationCatalog.getCertification(attempt.category);
  return certification ? certification.code : null;
}

function buildScoreTrend(attempts) {
  return attempts
    .slice()
    .sort((a, b) => new Date(a.completedAt) - new Date(b.completedAt))
    .map((attempt) => ({
      attemptId: attempt.attemptId,
      completedAt: attempt.completedAt,
      percentageScore: Number(attempt.percentageScore) || 0,
      labId: attempt.labId,
      labName: attempt.labName
    }));
}

function buildDomainMastery(certification, attempts) {
  const attemptsWithDomainData = attempts.filter(
    (attempt) => Array.isArray(attempt.domainBreakdown) && attempt.domainBreakdown.length > 0
  );

  const totals = new Map();
  attemptsWithDomainData.forEach((attempt) => {
    attempt.domainBreakdown.forEach((entry) => {
      const current = totals.get(entry.domainId) || {
        domainId: entry.domainId,
        domainName: entry.domainName,
        earned: 0,
        possible: 0,
        questionCount: 0
      };
      current.earned += Number(entry.earned) || 0;
      current.possible += Number(entry.possible) || 0;
      current.questionCount += Number(entry.questionCount) || 0;
      totals.set(entry.domainId, current);
    });
  });

  const blueprintDomains = certification?.blueprint?.domains || [];
  const domains = Array.from(totals.values()).map((entry) => {
    const blueprintDomain = blueprintDomains.find((domain) => domain.id === entry.domainId);
    return {
      ...entry,
      weightPercent: blueprintDomain ? blueprintDomain.weightPercent : null,
      masteryPercent: entry.possible > 0 ? Math.round((entry.earned / entry.possible) * 100) : null
    };
  });

  // Blueprint domains never practiced are reported with zero coverage so the
  // learner can see the gap (not silently omitted).
  blueprintDomains.forEach((domain) => {
    if (!totals.has(domain.id)) {
      domains.push({
        domainId: domain.id,
        domainName: domain.name,
        earned: 0,
        possible: 0,
        questionCount: 0,
        weightPercent: domain.weightPercent,
        masteryPercent: null
      });
    }
  });

  domains.sort((a, b) => (b.weightPercent || 0) - (a.weightPercent || 0) || a.domainName.localeCompare(b.domainName));

  return {
    attemptsWithDomainData: attemptsWithDomainData.length,
    totalAttempts: attempts.length,
    domains
  };
}

function buildReadiness(certification, attempts, domainMastery, now = new Date()) {
  if (attempts.length < MIN_ATTEMPTS_FOR_READINESS) {
    return {
      status: 'insufficient-evidence',
      detail: `${attempts.length} completed attempt(s); at least ${MIN_ATTEMPTS_FOR_READINESS} are needed before readiness is assessed.`,
      rules: []
    };
  }

  const threshold = certification?.passThresholdPercent;
  const chronological = buildScoreTrend(attempts);
  const latest = chronological[chronological.length - 1];
  const lastThree = chronological.slice(-3);
  const lastThreeMean = lastThree.reduce((sum, entry) => sum + entry.percentageScore, 0) / lastThree.length;
  const daysSinceLatest = (now - new Date(latest.completedAt)) / (24 * 60 * 60 * 1000);

  const rules = [];

  if (typeof threshold === 'number') {
    rules.push({
      id: 'latest-above-threshold',
      label: `Latest attempt at or above the ${threshold}% pass threshold`,
      satisfied: latest.percentageScore >= threshold,
      detail: `Latest score ${latest.percentageScore}%.`
    });
    rules.push({
      id: 'recent-average-above-threshold',
      label: `Average of the last ${lastThree.length} attempts at or above ${threshold}%`,
      satisfied: lastThreeMean >= threshold,
      detail: `Recent average ${Math.round(lastThreeMean)}%.`
    });
  }

  rules.push({
    id: 'practice-recency',
    label: `Practiced within the last ${RECENT_ATTEMPT_WINDOW_DAYS} days`,
    satisfied: daysSinceLatest <= RECENT_ATTEMPT_WINDOW_DAYS,
    detail: `Last attempt ${Math.floor(daysSinceLatest)} day(s) ago.`
  });

  const measuredDomains = domainMastery.domains.filter((domain) => domain.masteryPercent !== null);
  if (measuredDomains.length > 0) {
    const weakDomains = measuredDomains.filter((domain) => domain.masteryPercent < DOMAIN_FLOOR_PERCENT);
    rules.push({
      id: 'domain-floor',
      label: `No practiced domain below ${DOMAIN_FLOOR_PERCENT}% mastery`,
      satisfied: weakDomains.length === 0,
      detail: weakDomains.length === 0
        ? 'All practiced domains at or above the floor.'
        : `Below floor: ${weakDomains.map((domain) => `${domain.domainName} (${domain.masteryPercent}%)`).join(', ')}.`
    });
  } else {
    rules.push({
      id: 'domain-floor',
      label: `No practiced domain below ${DOMAIN_FLOOR_PERCENT}% mastery`,
      satisfied: null,
      detail: 'No attempts with domain data yet; complete a new exam to collect it.'
    });
  }

  return {
    status: 'assessed',
    detail: null,
    rules
  };
}

async function getAnalytics(now = new Date()) {
  const history = await attemptHistoryService.getAttempts();
  const attempts = history.attempts;

  const byCert = new Map();
  attempts.forEach((attempt) => {
    const code = getAttemptCertCode(attempt);
    if (!code) {
      return;
    }
    const list = byCert.get(code) || [];
    list.push(attempt);
    byCert.set(code, list);
  });

  const certifications = certificationCatalog.loadCatalog().certifications.map((certification) => {
    const certAttempts = byCert.get(certification.code) || [];
    const scoreTrend = buildScoreTrend(certAttempts);
    const domainMastery = buildDomainMastery(certification, certAttempts);

    return {
      code: certification.code,
      displayName: certification.displayName,
      examFormat: certification.examFormat,
      passThresholdPercent: certification.passThresholdPercent,
      blueprintVersion: certification.blueprint?.version || null,
      attemptCount: certAttempts.length,
      latestPercentage: scoreTrend.length ? scoreTrend[scoreTrend.length - 1].percentageScore : null,
      bestPercentage: scoreTrend.length ? Math.max(...scoreTrend.map((entry) => entry.percentageScore)) : null,
      scoreTrend,
      domainMastery,
      readiness: buildReadiness(certification, certAttempts, domainMastery, now)
    };
  });

  return {
    generatedAt: now.toISOString(),
    totalAttempts: attempts.length,
    uncategorizedAttempts: attempts.filter((attempt) => !getAttemptCertCode(attempt)).length,
    certifications
  };
}

module.exports = {
  getAnalytics,
  // exported for focused unit tests
  buildDomainMastery,
  buildReadiness,
  buildScoreTrend
};
