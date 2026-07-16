/**
 * Tests for Mistake Service
 *
 * Verifies the plan §10 rules: capture ≠ corrected, retest pass ≠ resolved
 * without a completed correction, resolved requires both.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ckx-mistakes-test-'));
process.env.MISTAKES_FILE = path.join(tempDir, 'mistakes.json');

const mistakeService = require('../src/services/mistakeService');

function capturePayload(overrides = {}) {
  return {
    summary: 'NetworkPolicy default deny missing',
    category: 'concept-gap',
    rootCauseNote: 'Forgot podSelector: {} selects all pods',
    source: {
      attemptId: 'attempt-1',
      questionId: '1',
      labId: 'cks-004',
      labName: 'CKS Mock 3',
      certificationCode: 'CKS',
      concepts: ['network policies'],
      failedValidationSteps: [{ id: '2', description: 'policy admits only trusted ns' }]
    },
    ...overrides
  };
}

describe('Mistake Service', () => {
  afterAll(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  let mistakeId;

  it('captures a mistake that starts uncorrected and unresolved', async () => {
    const result = await mistakeService.createMistake(capturePayload());

    expect(result.created).toBe(true);
    expect(result.mistake.correction.status).toBe('none');
    expect(result.mistake.resolved).toBe(false);
    mistakeId = result.mistake.mistakeId;
  });

  it('rejects malformed capture payloads', async () => {
    const missingSource = await mistakeService.createMistake({ summary: 'x' });
    expect(missingSource.created).toBe(false);

    const badCategory = await mistakeService.createMistake(capturePayload({
      category: 'not-a-category',
      source: { attemptId: 'a2', questionId: '9' }
    }));
    expect(badCategory.created).toBe(false);
  });

  it('deduplicates by attempt + question source', async () => {
    const duplicate = await mistakeService.createMistake(capturePayload());
    expect(duplicate.created).toBe(false);
    expect(duplicate.duplicate).toBe(true);
    expect(duplicate.mistake.mistakeId).toBe(mistakeId);

    const list = await mistakeService.listMistakes();
    expect(list.counts.total).toBe(1);
  });

  it('a passed retest alone does NOT resolve the mistake (correction still none)', async () => {
    const scheduled = await mistakeService.scheduleRetest(mistakeId, { scheduledFor: '2026-07-20' });
    expect(scheduled.scheduled).toBe(true);

    const recorded = await mistakeService.recordRetestResult(
      mistakeId,
      scheduled.retest.retestId,
      { result: 'passed' }
    );
    expect(recorded.recorded).toBe(true);
    expect(recorded.mistake.correction.status).toBe('none');
    expect(recorded.mistake.resolved).toBe(false);
  });

  it('completing the correction alone does NOT resolve without a decided retest outcome after it', async () => {
    // Fresh mistake with no retests
    const fresh = await mistakeService.createMistake(capturePayload({
      source: { attemptId: 'attempt-2', questionId: '3', certificationCode: 'CKS' }
    }));
    const freshId = fresh.mistake.mistakeId;

    const corrected = await mistakeService.updateCorrection(freshId, { status: 'done', note: 'Re-read docs, drilled 3 policies' });
    expect(corrected.updated).toBe(true);
    expect(corrected.mistake.correction.status).toBe('done');
    expect(corrected.mistake.correction.completedAt).toBeTruthy();
    expect(corrected.mistake.resolved).toBe(false); // no retest yet
  });

  it('resolved requires correction done AND latest retest passed', async () => {
    const corrected = await mistakeService.updateCorrection(mistakeId, { status: 'done' });
    expect(corrected.mistake.resolved).toBe(true); // earlier retest passed + now corrected

    // A newer failed retest flips it back to unresolved
    const scheduled = await mistakeService.scheduleRetest(mistakeId, { scheduledFor: '2026-07-25' });
    const failed = await mistakeService.recordRetestResult(
      mistakeId,
      scheduled.retest.retestId,
      { result: 'failed' }
    );
    expect(failed.mistake.resolved).toBe(false);
    expect(failed.mistake.failedRetests).toBe(1);
  });

  it('lists a pending retest queue sorted by date', async () => {
    await mistakeService.scheduleRetest(mistakeId, { scheduledFor: '2026-08-01' });
    const list = await mistakeService.listMistakes();

    expect(list.counts.pendingRetests).toBe(1);
    expect(list.retestQueue[0].scheduledFor).toBe('2026-08-01');
  });

  it('filters by resolved state and category', async () => {
    const unresolvedOnly = await mistakeService.listMistakes({ resolved: 'false' });
    expect(unresolvedOnly.mistakes.length).toBe(2);

    const conceptGap = await mistakeService.listMistakes({ category: 'concept-gap' });
    expect(conceptGap.mistakes.length).toBe(2);
  });

  it('export/restore round trip preserves records', async () => {
    const exported = await mistakeService.exportMistakes();
    expect(exported.mistakes.length).toBe(2);

    const restored = await mistakeService.restoreMistakes(exported);
    expect(restored.restored).toBe(true);
    expect(restored.mistakeCount).toBe(2);

    const rejected = await mistakeService.restoreMistakes({ nope: true });
    expect(rejected.restored).toBe(false);
  });

  it('deletes a mistake', async () => {
    const before = await mistakeService.listMistakes();
    const target = before.mistakes.find((mistake) => mistake.source.attemptId === 'attempt-2');

    const result = await mistakeService.deleteMistake(target.mistakeId);
    expect(result.deleted).toBe(true);

    const after = await mistakeService.listMistakes();
    expect(after.counts.total).toBe(1);
  });
});
