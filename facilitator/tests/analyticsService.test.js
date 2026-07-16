/**
 * Tests for Analytics Service
 *
 * Metric definitions from docs/CK_X_PRODUCT_AND_IMPLEMENTATION_PLAN.md §9:
 * analytics derive only from stored attempts; insufficient evidence is
 * reported, never replaced with an invented number.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ckx-analytics-test-'));
process.env.ATTEMPT_HISTORY_FILE = path.join(tempDir, 'attempt-history.json');

const analyticsService = require('../src/services/analyticsService');
const certificationCatalog = require('../src/utils/certificationCatalog');

const NOW = new Date('2026-07-16T12:00:00.000Z');
const cka = certificationCatalog.getCertification('CKA');

function attempt(overrides = {}) {
  return {
    attemptId: `a-${Math.random().toString(36).slice(2)}`,
    certificationCode: 'CKA',
    category: 'CKA',
    labId: 'cka-004',
    labName: 'CKA Mock',
    completedAt: '2026-07-10T10:00:00.000Z',
    percentageScore: 70,
    domainBreakdown: [],
    ...overrides
  };
}

describe('Analytics Service', () => {
  afterAll(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  describe('buildScoreTrend', () => {
    it('returns attempts in chronological order', () => {
      const trend = analyticsService.buildScoreTrend([
        attempt({ completedAt: '2026-07-12T10:00:00.000Z', percentageScore: 80 }),
        attempt({ completedAt: '2026-07-01T10:00:00.000Z', percentageScore: 40 })
      ]);
      expect(trend.map((entry) => entry.percentageScore)).toEqual([40, 80]);
    });
  });

  describe('buildDomainMastery', () => {
    it('aggregates earned/possible per domain and reports unpracticed blueprint domains', () => {
      const attempts = [
        attempt({
          domainBreakdown: [
            { domainId: 'cka-storage', domainName: 'Storage', earned: 5, possible: 10, questionCount: 2 }
          ]
        }),
        attempt({
          domainBreakdown: [
            { domainId: 'cka-storage', domainName: 'Storage', earned: 10, possible: 10, questionCount: 2 }
          ]
        })
      ];

      const mastery = analyticsService.buildDomainMastery(cka, attempts);

      expect(mastery.attemptsWithDomainData).toBe(2);
      const storage = mastery.domains.find((domain) => domain.domainId === 'cka-storage');
      expect(storage.earned).toBe(15);
      expect(storage.possible).toBe(20);
      expect(storage.masteryPercent).toBe(75);
      expect(storage.weightPercent).toBe(10);

      // Unpracticed blueprint domains appear with null mastery, not omitted
      const troubleshooting = mastery.domains.find((domain) => domain.domainId === 'cka-troubleshooting');
      expect(troubleshooting).toBeDefined();
      expect(troubleshooting.masteryPercent).toBeNull();
    });

    it('counts attempts without domain data separately (v1 records)', () => {
      const mastery = analyticsService.buildDomainMastery(cka, [
        attempt({ domainBreakdown: undefined }),
        attempt({
          domainBreakdown: [
            { domainId: 'cka-storage', domainName: 'Storage', earned: 2, possible: 4, questionCount: 1 }
          ]
        })
      ]);
      expect(mastery.attemptsWithDomainData).toBe(1);
      expect(mastery.totalAttempts).toBe(2);
    });
  });

  describe('buildReadiness', () => {
    it('reports insufficient evidence below two attempts and defines no rules', () => {
      const readiness = analyticsService.buildReadiness(cka, [attempt()], { domains: [] }, NOW);
      expect(readiness.status).toBe('insufficient-evidence');
      expect(readiness.rules).toEqual([]);
    });

    it('assesses transparent rules once evidence exists', () => {
      const attempts = [
        attempt({ completedAt: '2026-07-01T10:00:00.000Z', percentageScore: 50 }),
        attempt({ completedAt: '2026-07-14T10:00:00.000Z', percentageScore: 70 })
      ];
      const mastery = analyticsService.buildDomainMastery(cka, attempts);
      const readiness = analyticsService.buildReadiness(cka, attempts, mastery, NOW);

      expect(readiness.status).toBe('assessed');
      const byId = Object.fromEntries(readiness.rules.map((rule) => [rule.id, rule]));

      // Latest 70% >= CKA threshold 66%
      expect(byId['latest-above-threshold'].satisfied).toBe(true);
      // Mean of (50, 70) = 60 < 66
      expect(byId['recent-average-above-threshold'].satisfied).toBe(false);
      // Latest attempt 2 days before NOW
      expect(byId['practice-recency'].satisfied).toBe(true);
      // No domain data at all -> rule reports null (no evidence), not pass/fail
      expect(byId['domain-floor'].satisfied).toBeNull();
    });

    it('fails the domain floor when a practiced domain is below 50%', () => {
      const attempts = [
        attempt({
          completedAt: '2026-07-13T10:00:00.000Z',
          domainBreakdown: [
            { domainId: 'cka-storage', domainName: 'Storage', earned: 1, possible: 10, questionCount: 2 }
          ]
        }),
        attempt({
          completedAt: '2026-07-14T10:00:00.000Z',
          domainBreakdown: [
            { domainId: 'cka-storage', domainName: 'Storage', earned: 2, possible: 10, questionCount: 2 }
          ]
        })
      ];
      const mastery = analyticsService.buildDomainMastery(cka, attempts);
      const readiness = analyticsService.buildReadiness(cka, attempts, mastery, NOW);
      const domainRule = readiness.rules.find((rule) => rule.id === 'domain-floor');

      expect(domainRule.satisfied).toBe(false);
      expect(domainRule.detail).toContain('Storage');
    });
  });

  describe('getAnalytics', () => {
    it('returns all five certifications with honest empty states when history is empty', async () => {
      const analytics = await analyticsService.getAnalytics(NOW);

      expect(analytics.totalAttempts).toBe(0);
      expect(analytics.certifications).toHaveLength(5);
      analytics.certifications.forEach((cert) => {
        expect(cert.attemptCount).toBe(0);
        expect(cert.latestPercentage).toBeNull();
        expect(cert.readiness.status).toBe('insufficient-evidence');
      });
    });
  });
});
