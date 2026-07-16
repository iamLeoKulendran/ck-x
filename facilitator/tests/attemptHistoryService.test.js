/**
 * Tests for Attempt History Service (schema v2)
 *
 * Uses a temp history file via ATTEMPT_HISTORY_FILE so no real data is touched.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ckx-history-test-'));
process.env.ATTEMPT_HISTORY_FILE = path.join(tempDir, 'attempt-history.json');

const attemptHistoryService = require('../src/services/attemptHistoryService');

const examInfo = {
  id: 'cka-004',
  name: 'CKA Mock Exam',
  category: 'CKA',
  assetPath: 'assets/exams/cka/004',
  difficulty: 'Hard',
  createdAt: '2026-07-01T10:00:00.000Z',
  events: {
    examStartTime: '2026-07-01T10:05:00.000Z'
  }
};

function buildResult(overrides = {}) {
  return {
    totalScore: 60,
    totalPossibleScore: 100,
    percentageScore: 60,
    rank: 'medium',
    completedAt: '2026-07-01T12:00:00.000Z',
    evaluationResults: [
      {
        id: '1',
        namespace: 'ns-a',
        concepts: ['rbac'],
        verificationResults: [
          { id: '1', description: 'role exists', validAnswer: true, weightage: 4, score: 4 },
          { id: '2', description: 'binding works', validAnswer: false, weightage: 4, score: 0 }
        ]
      },
      {
        id: '2',
        namespace: 'ns-b',
        concepts: ['services'],
        verificationResults: [
          { id: '1', description: 'service reachable', validAnswer: true, weightage: 5, score: 5 }
        ]
      }
    ],
    ...overrides
  };
}

describe('Attempt History Service', () => {
  afterAll(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  describe('buildAttemptRecord (v2)', () => {
    it('captures lab metadata, scores, and failed questions with failed steps only', () => {
      const record = attemptHistoryService.buildAttemptRecord('exam-1', examInfo, buildResult());

      expect(record.schemaVersion).toBe(2);
      expect(record.labId).toBe('cka-004');
      expect(record.category).toBe('CKA');
      expect(record.percentageScore).toBe(60);
      expect(record.scoreLevel).toBe('medium');

      // Only question 1 has a failed step; question 2 passed fully
      expect(record.failedQuestions).toHaveLength(1);
      expect(record.failedQuestions[0].id).toBe('1');
      expect(record.failedQuestions[0].failedValidationSteps).toEqual([
        expect.objectContaining({ id: '2', weightage: 4 })
      ]);
      expect(record.failedConcepts).toEqual([
        expect.objectContaining({ name: 'rbac', failedQuestionCount: 1, failedStepCount: 1 })
      ]);
    });

    it('adds v2 fields: mode, duration, certification, blueprint, domain breakdown', () => {
      const record = attemptHistoryService.buildAttemptRecord('exam-1', examInfo, buildResult());

      expect(record.mode).toBe('timed');
      // 10:05:00 -> 12:00:00 = 1h55m = 6900 seconds
      expect(record.durationUsedSeconds).toBe(6900);
      expect(record.certificationCode).toBe('CKA');
      expect(record.blueprintVersion).toBe('v1.35');

      // rbac maps to cluster architecture; services maps to services & networking
      const domainIds = record.domainBreakdown.map((entry) => entry.domainId);
      expect(domainIds).toContain('cka-cluster-architecture');
      expect(domainIds).toContain('cka-services-networking');

      const rbacDomain = record.domainBreakdown.find((entry) => entry.domainId === 'cka-cluster-architecture');
      expect(rbacDomain.earned).toBe(4);
      expect(rbacDomain.possible).toBe(8);
      expect(rbacDomain.questionCount).toBe(1);
    });

    it('handles unknown categories and missing start times gracefully', () => {
      const record = attemptHistoryService.buildAttemptRecord(
        'exam-x',
        { ...examInfo, category: 'Other', events: {} },
        buildResult()
      );

      expect(record.certificationCode).toBeNull();
      expect(record.blueprintVersion).toBeNull();
      expect(record.domainBreakdown).toEqual([]);
      expect(record.durationUsedSeconds).toBeNull();
    });

    it('assigns score level from percentage when rank is missing', () => {
      const record = attemptHistoryService.buildAttemptRecord(
        'exam-2',
        examInfo,
        buildResult({ rank: undefined, percentageScore: 85 })
      );
      expect(record.scoreLevel).toBe('high');
    });
  });

  describe('appendAttempt + getAttempts', () => {
    it('appends attempts and returns them newest-first with summary and filters', async () => {
      await attemptHistoryService.appendAttempt('exam-1', examInfo, buildResult({
        completedAt: '2026-07-01T12:00:00.000Z'
      }));
      await attemptHistoryService.appendAttempt('exam-2', examInfo, buildResult({
        completedAt: '2026-07-02T12:00:00.000Z',
        totalScore: 80,
        percentageScore: 80,
        rank: 'high'
      }));

      const history = await attemptHistoryService.getAttempts();

      expect(history.version).toBe(2);
      expect(history.attempts).toHaveLength(2);
      expect(history.attempts[0].examSessionId).toBe('exam-2');
      expect(history.summary.totalAttempts).toBe(2);
      expect(history.summary.mostFailedConcepts[0]).toEqual(
        expect.objectContaining({ name: 'rbac', count: 2 })
      );
      expect(history.summary.improvementTrend[0]).toEqual(
        expect.objectContaining({ labId: 'cka-004', delta: 20 })
      );
      expect(history.filters.categories).toEqual(['CKA']);
    });

    it('filters by category and failed concept', async () => {
      const byCategory = await attemptHistoryService.getAttempts({ category: 'CKS' });
      expect(byCategory.attempts).toHaveLength(0);

      const byConcept = await attemptHistoryService.getAttempts({ failedConcept: 'rbac' });
      expect(byConcept.attempts).toHaveLength(2);
    });

    it('persists to disk with the v2 version envelope', async () => {
      const raw = JSON.parse(fs.readFileSync(process.env.ATTEMPT_HISTORY_FILE, 'utf8'));
      expect(raw.version).toBe(2);
      expect(Array.isArray(raw.attempts)).toBe(true);
      expect(raw.attempts).toHaveLength(2);
    });
  });

  describe('v1 file migration', () => {
    it('backs up a v1 file before writing the v2 envelope and keeps v1 records readable', async () => {
      const v1Attempt = {
        attemptId: 'legacy-1',
        examSessionId: 'legacy-session',
        labId: 'cka-001',
        labName: 'Legacy Lab',
        category: 'CKA',
        completedAt: '2026-06-01T10:00:00.000Z',
        totalScore: 50,
        totalPossibleScore: 100,
        percentageScore: 50,
        scoreLevel: 'low',
        failedQuestions: [],
        failedConcepts: [],
        failedValidationSteps: []
      };

      fs.writeFileSync(
        process.env.ATTEMPT_HISTORY_FILE,
        JSON.stringify({ version: 1, attempts: [v1Attempt] })
      );

      await attemptHistoryService.appendAttempt('exam-3', examInfo, buildResult());

      // Backup of the v1 file exists and contains only the legacy record
      const backupPath = `${process.env.ATTEMPT_HISTORY_FILE}.v1.bak`;
      expect(fs.existsSync(backupPath)).toBe(true);
      const backup = JSON.parse(fs.readFileSync(backupPath, 'utf8'));
      expect(backup.version).toBe(1);
      expect(backup.attempts).toHaveLength(1);

      // The live file upgraded to v2 and keeps the untouched v1 record
      const raw = JSON.parse(fs.readFileSync(process.env.ATTEMPT_HISTORY_FILE, 'utf8'));
      expect(raw.version).toBe(2);
      expect(raw.attempts).toHaveLength(2);
      const legacy = raw.attempts.find((attempt) => attempt.attemptId === 'legacy-1');
      expect(legacy).toEqual(v1Attempt);

      // getAttempts serves both generations
      const history = await attemptHistoryService.getAttempts();
      expect(history.attempts).toHaveLength(2);
    });
  });

  describe('deleteAttempt', () => {
    it('removes one attempt after writing a backup', async () => {
      const before = await attemptHistoryService.getAttempts();
      const target = before.attempts.find((attempt) => attempt.attemptId === 'legacy-1');
      expect(target).toBeDefined();

      const result = await attemptHistoryService.deleteAttempt('legacy-1');
      expect(result.deleted).toBe(true);
      expect(fs.existsSync(result.backupPath)).toBe(true);

      const after = await attemptHistoryService.getAttempts();
      expect(after.attempts.find((attempt) => attempt.attemptId === 'legacy-1')).toBeUndefined();
    });

    it('returns not-found for unknown attempt ids', async () => {
      const result = await attemptHistoryService.deleteAttempt('does-not-exist');
      expect(result.deleted).toBe(false);
      expect(result.reason).toBe('not-found');
    });
  });

  describe('export / restore / reset round trip', () => {
    it('export produces a bundle that restore accepts (round trip preserves attempts)', async () => {
      const bundle = await attemptHistoryService.exportHistory();
      expect(bundle.exportedAt).toBeDefined();
      expect(bundle.attempts.length).toBeGreaterThan(0);

      const reset = await attemptHistoryService.resetHistory();
      expect(reset.reset).toBe(true);
      expect(fs.existsSync(reset.backupPath)).toBe(true);

      const emptied = await attemptHistoryService.getAttempts();
      expect(emptied.attempts).toHaveLength(0);

      const restore = await attemptHistoryService.restoreHistory(bundle);
      expect(restore.restored).toBe(true);

      const restored = await attemptHistoryService.getAttempts();
      expect(restored.attempts).toHaveLength(bundle.attempts.length);
    });

    it('rejects malformed restore payloads without touching the file', async () => {
      const before = await attemptHistoryService.getAttempts();

      const cases = [
        null,
        {},
        { attempts: 'nope' },
        { attempts: [{ attemptId: 'x' }] },
        { attempts: [{ attemptId: 'x', completedAt: 'not-a-date', percentageScore: 10 }] },
        { attempts: [{ attemptId: 'x', completedAt: '2026-07-01T00:00:00Z', percentageScore: 'high' }] }
      ];

      for (const payload of cases) {
        const result = await attemptHistoryService.restoreHistory(payload);
        expect(result.restored).toBe(false);
        expect(typeof result.error).toBe('string');
      }

      const after = await attemptHistoryService.getAttempts();
      expect(after.attempts).toHaveLength(before.attempts.length);
    });
  });
});
