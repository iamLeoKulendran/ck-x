/**
 * Mistake Service
 *
 * Persistent mistake-correction and retest tracking. Follows the same
 * storage pattern as attemptHistoryService: one JSON file with a version
 * envelope, atomic temp-file writes, and a serialized write queue.
 *
 * Core rules (docs/CK_X_PRODUCT_AND_IMPLEMENTATION_PLAN.md §10):
 * - Capturing a mistake never marks it corrected.
 * - A passed retest never implies the correction was performed.
 * - "Resolved" requires correction.status === 'done' AND the latest retest passed.
 */

const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const logger = require('../utils/logger');

const MISTAKES_VERSION = 1;
const DEFAULT_MISTAKES_FILE = '/usr/src/app/data/mistakes.json';
const mistakesFilePath = process.env.MISTAKES_FILE || DEFAULT_MISTAKES_FILE;

const MISTAKE_CATEGORIES = [
  'concept-gap',
  'syntax',
  'misread-question',
  'time-pressure',
  'environment',
  'other'
];

const CORRECTION_STATUSES = ['none', 'planned', 'done'];
const RETEST_RESULTS = ['pending', 'passed', 'failed'];

let writeQueue = Promise.resolve();

function enqueueWrite(operation) {
  const nextWrite = writeQueue.then(operation, operation);
  writeQueue = nextWrite.catch((error) => {
    logger.error('Mistake store write failed', { error: error.message });
  });
  return nextWrite;
}

function getMistakesFilePath() {
  return mistakesFilePath;
}

async function writeAtomic(document) {
  const directory = path.dirname(mistakesFilePath);
  await fs.promises.mkdir(directory, { recursive: true });

  const tempPath = `${mistakesFilePath}.${process.pid}.${Date.now()}.tmp`;
  await fs.promises.writeFile(tempPath, JSON.stringify(document, null, 2), 'utf8');
  await fs.promises.rename(tempPath, mistakesFilePath);
}

async function readStore() {
  try {
    const contents = await fs.promises.readFile(mistakesFilePath, 'utf8');
    const store = JSON.parse(contents || '{}');
    if (!store || !Array.isArray(store.mistakes)) {
      throw new Error('Mistake store has an invalid format');
    }
    return { version: store.version || MISTAKES_VERSION, mistakes: store.mistakes };
  } catch (error) {
    if (error.code === 'ENOENT') {
      return { version: MISTAKES_VERSION, mistakes: [] };
    }
    throw error;
  }
}

/**
 * Resolved is derived, never stored: the remedy was completed AND the most
 * recent retest with a recorded outcome passed.
 */
function isResolved(mistake) {
  if (mistake.correction?.status !== 'done') {
    return false;
  }

  const decidedRetests = (mistake.retests || []).filter((retest) => retest.result !== 'pending');
  if (decidedRetests.length === 0) {
    return false;
  }

  const latest = decidedRetests[decidedRetests.length - 1];
  return latest.result === 'passed';
}

function withDerivedFields(mistake) {
  const retests = mistake.retests || [];
  return {
    ...mistake,
    resolved: isResolved(mistake),
    pendingRetests: retests.filter((retest) => retest.result === 'pending').length,
    failedRetests: retests.filter((retest) => retest.result === 'failed').length
  };
}

function validateCreatePayload(payload) {
  if (!payload || typeof payload !== 'object') {
    return 'Payload must be a JSON object';
  }
  if (!payload.source || typeof payload.source !== 'object') {
    return 'source is required ({ attemptId, questionId, ... })';
  }
  if (!payload.source.attemptId || !payload.source.questionId) {
    return 'source.attemptId and source.questionId are required';
  }
  if (payload.category && !MISTAKE_CATEGORIES.includes(payload.category)) {
    return `category must be one of: ${MISTAKE_CATEGORIES.join(', ')}`;
  }
  return null;
}

async function listMistakes(filters = {}) {
  const store = await readStore();
  let mistakes = store.mistakes.map(withDerivedFields);

  if (filters.category) {
    mistakes = mistakes.filter((mistake) => mistake.category === filters.category);
  }
  if (filters.resolved === 'true') {
    mistakes = mistakes.filter((mistake) => mistake.resolved);
  } else if (filters.resolved === 'false') {
    mistakes = mistakes.filter((mistake) => !mistake.resolved);
  }
  if (filters.certificationCode) {
    mistakes = mistakes.filter((mistake) => mistake.source?.certificationCode === filters.certificationCode);
  }

  mistakes.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  const retestQueue = store.mistakes
    .flatMap((mistake) => (mistake.retests || [])
      .filter((retest) => retest.result === 'pending')
      .map((retest) => ({
        mistakeId: mistake.mistakeId,
        retestId: retest.retestId,
        scheduledFor: retest.scheduledFor,
        summary: mistake.summary || `Question ${mistake.source?.questionId} in ${mistake.source?.labName || mistake.source?.labId || 'unknown lab'}`
      })))
    .sort((a, b) => String(a.scheduledFor).localeCompare(String(b.scheduledFor)));

  return {
    version: store.version,
    mistakes,
    retestQueue,
    counts: {
      total: store.mistakes.length,
      resolved: mistakes.filter((mistake) => mistake.resolved).length,
      correctionDone: store.mistakes.filter((mistake) => mistake.correction?.status === 'done').length,
      pendingRetests: retestQueue.length
    },
    categories: MISTAKE_CATEGORIES
  };
}

async function createMistake(payload) {
  const validationError = validateCreatePayload(payload);
  if (validationError) {
    return { created: false, error: validationError };
  }

  return enqueueWrite(async () => {
    const store = await readStore();

    // Duplicate guard: one mistake per attempt+question source
    const existing = store.mistakes.find((mistake) => (
      mistake.source?.attemptId === payload.source.attemptId &&
      String(mistake.source?.questionId) === String(payload.source.questionId)
    ));
    if (existing) {
      return { created: false, duplicate: true, mistake: withDerivedFields(existing) };
    }

    const mistake = {
      mistakeId: randomUUID(),
      createdAt: new Date().toISOString(),
      summary: payload.summary || '',
      category: payload.category || 'other',
      rootCauseNote: payload.rootCauseNote || '',
      source: {
        attemptId: payload.source.attemptId,
        questionId: String(payload.source.questionId),
        labId: payload.source.labId || '',
        labName: payload.source.labName || '',
        certificationCode: payload.source.certificationCode || null,
        concepts: Array.isArray(payload.source.concepts) ? payload.source.concepts : [],
        failedValidationSteps: Array.isArray(payload.source.failedValidationSteps)
          ? payload.source.failedValidationSteps
          : []
      },
      // A new mistake is never corrected at capture time
      correction: { status: 'none', note: '', completedAt: null },
      retests: []
    };

    store.mistakes.push(mistake);
    await writeAtomic({ version: MISTAKES_VERSION, mistakes: store.mistakes });
    logger.info('Captured mistake', { mistakeId: mistake.mistakeId });
    return { created: true, mistake: withDerivedFields(mistake) };
  });
}

async function updateCorrection(mistakeId, payload) {
  if (!payload || !CORRECTION_STATUSES.includes(payload.status)) {
    return { updated: false, error: `correction status must be one of: ${CORRECTION_STATUSES.join(', ')}` };
  }

  return enqueueWrite(async () => {
    const store = await readStore();
    const mistake = store.mistakes.find((entry) => entry.mistakeId === mistakeId);
    if (!mistake) {
      return { updated: false, error: 'not-found' };
    }

    mistake.correction = {
      status: payload.status,
      note: typeof payload.note === 'string' ? payload.note : (mistake.correction?.note || ''),
      completedAt: payload.status === 'done'
        ? (mistake.correction?.completedAt || new Date().toISOString())
        : null
    };

    await writeAtomic({ version: MISTAKES_VERSION, mistakes: store.mistakes });
    return { updated: true, mistake: withDerivedFields(mistake) };
  });
}

async function scheduleRetest(mistakeId, payload = {}) {
  return enqueueWrite(async () => {
    const store = await readStore();
    const mistake = store.mistakes.find((entry) => entry.mistakeId === mistakeId);
    if (!mistake) {
      return { scheduled: false, error: 'not-found' };
    }

    const retest = {
      retestId: randomUUID(),
      scheduledFor: payload.scheduledFor || new Date().toISOString().slice(0, 10),
      createdAt: new Date().toISOString(),
      result: 'pending',
      resultRecordedAt: null,
      note: payload.note || ''
    };

    mistake.retests = mistake.retests || [];
    mistake.retests.push(retest);

    await writeAtomic({ version: MISTAKES_VERSION, mistakes: store.mistakes });
    return { scheduled: true, mistake: withDerivedFields(mistake), retest };
  });
}

async function recordRetestResult(mistakeId, retestId, payload) {
  if (!payload || !RETEST_RESULTS.includes(payload.result) || payload.result === 'pending') {
    return { recorded: false, error: 'result must be "passed" or "failed"' };
  }

  return enqueueWrite(async () => {
    const store = await readStore();
    const mistake = store.mistakes.find((entry) => entry.mistakeId === mistakeId);
    if (!mistake) {
      return { recorded: false, error: 'not-found' };
    }

    const retest = (mistake.retests || []).find((entry) => entry.retestId === retestId);
    if (!retest) {
      return { recorded: false, error: 'retest-not-found' };
    }

    retest.result = payload.result;
    retest.resultRecordedAt = new Date().toISOString();
    if (typeof payload.note === 'string' && payload.note) {
      retest.note = payload.note;
    }

    await writeAtomic({ version: MISTAKES_VERSION, mistakes: store.mistakes });
    return { recorded: true, mistake: withDerivedFields(mistake) };
  });
}

async function deleteMistake(mistakeId) {
  return enqueueWrite(async () => {
    const store = await readStore();
    const index = store.mistakes.findIndex((entry) => entry.mistakeId === mistakeId);
    if (index === -1) {
      return { deleted: false, error: 'not-found' };
    }

    store.mistakes.splice(index, 1);
    await writeAtomic({ version: MISTAKES_VERSION, mistakes: store.mistakes });
    return { deleted: true };
  });
}

/**
 * Raw document for the data export bundle.
 */
async function exportMistakes() {
  const store = await readStore();
  return store;
}

/**
 * Replace the mistake store from an export bundle (used by data restore).
 * The current file, when present, is backed up first.
 */
async function restoreMistakes(document) {
  if (!document || !Array.isArray(document.mistakes)) {
    return { restored: false, error: 'Mistake bundle must contain a "mistakes" array' };
  }

  return enqueueWrite(async () => {
    try {
      await fs.promises.access(mistakesFilePath, fs.constants.F_OK);
      const backupPath = `${mistakesFilePath}.pre-restore.${Date.now()}.bak`;
      await fs.promises.copyFile(mistakesFilePath, backupPath);
    } catch (error) {
      if (error.code !== 'ENOENT') {
        throw error;
      }
    }

    await writeAtomic({ version: MISTAKES_VERSION, mistakes: document.mistakes });
    return { restored: true, mistakeCount: document.mistakes.length };
  });
}

module.exports = {
  listMistakes,
  createMistake,
  updateCorrection,
  scheduleRetest,
  recordRetestResult,
  deleteMistake,
  exportMistakes,
  restoreMistakes,
  getMistakesFilePath,
  isResolved,
  MISTAKE_CATEGORIES
};
