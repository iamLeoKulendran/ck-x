const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const logger = require('../utils/logger');
const certificationCatalog = require('../utils/certificationCatalog');

// v2 adds per-attempt mode, durationUsedSeconds, certificationCode,
// blueprintVersion, and domainBreakdown. v1 records remain valid and are
// never rewritten; the file envelope upgrades to 2 on the next write after
// a one-time .v1.bak backup.
const HISTORY_VERSION = 2;
const SUPPORTED_HISTORY_VERSIONS = [1, 2];
const DEFAULT_HISTORY_FILE = '/usr/src/app/data/attempt-history.json';
const historyFilePath = process.env.ATTEMPT_HISTORY_FILE || DEFAULT_HISTORY_FILE;

let writeQueue = Promise.resolve();

function getHistoryFilePath() {
  return historyFilePath;
}

async function ensureHistoryFile() {
  const directory = path.dirname(historyFilePath);
  await fs.promises.mkdir(directory, { recursive: true });

  try {
    await fs.promises.access(historyFilePath, fs.constants.F_OK);
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error;
    }

    await writeHistoryAtomic({
      version: HISTORY_VERSION,
      attempts: []
    });
  }
}

async function readHistory() {
  await ensureHistoryFile();

  const fileContents = await fs.promises.readFile(historyFilePath, 'utf8');
  const history = JSON.parse(fileContents || '{}');

  if (!history || !Array.isArray(history.attempts)) {
    throw new Error('Attempt history file has an invalid format');
  }

  const version = history.version || 1;
  if (!SUPPORTED_HISTORY_VERSIONS.includes(version)) {
    throw new Error(`Unsupported attempt history version: ${version}`);
  }

  return {
    version,
    attempts: history.attempts
  };
}

// One-time backup of the v1 file before the envelope upgrades to v2.
async function backupBeforeUpgrade(currentVersion) {
  if (currentVersion >= HISTORY_VERSION) {
    return;
  }

  const backupPath = `${historyFilePath}.v${currentVersion}.bak`;
  try {
    await fs.promises.access(backupPath, fs.constants.F_OK);
    return; // backup already exists
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error;
    }
  }

  await fs.promises.copyFile(historyFilePath, backupPath);
  logger.info('Backed up attempt history before schema upgrade', { backupPath });
}

async function writeHistoryAtomic(history) {
  const directory = path.dirname(historyFilePath);
  await fs.promises.mkdir(directory, { recursive: true });

  const tempPath = `${historyFilePath}.${process.pid}.${Date.now()}.tmp`;
  const payload = JSON.stringify(history, null, 2);

  await fs.promises.writeFile(tempPath, payload, 'utf8');
  await fs.promises.rename(tempPath, historyFilePath);
}

function enqueueWrite(operation) {
  const nextWrite = writeQueue.then(operation, operation);
  writeQueue = nextWrite.catch((error) => {
    logger.error('Attempt history write failed', { error: error.message });
  });
  return nextWrite;
}

function getScoreLevel(percentageScore) {
  if (percentageScore >= 80) {
    return 'high';
  }

  if (percentageScore >= 60) {
    return 'medium';
  }

  return 'low';
}

function getQuestionScore(questionResult) {
  const verificationResults = questionResult.verificationResults || [];
  return verificationResults.reduce((total, verification) => total + (Number(verification.score) || 0), 0);
}

function getQuestionPossibleScore(questionResult) {
  const verificationResults = questionResult.verificationResults || [];
  return verificationResults.reduce((total, verification) => total + (Number(verification.weightage) || 0), 0);
}

function getFailedQuestions(evaluationResults) {
  return (evaluationResults || [])
    .map((questionResult) => {
      const failedValidationSteps = (questionResult.verificationResults || [])
        .filter((verification) => !verification.validAnswer)
        .map((verification) => ({
          id: String(verification.id),
          description: verification.description || '',
          weightage: Number(verification.weightage) || 0
        }));

      if (failedValidationSteps.length === 0) {
        return null;
      }

      return {
        id: String(questionResult.id),
        namespace: questionResult.namespace || '',
        questionTitle: `Question ${questionResult.id}`,
        concepts: questionResult.concepts || ['Uncategorized'],
        score: getQuestionScore(questionResult),
        possibleScore: getQuestionPossibleScore(questionResult),
        failedValidationSteps
      };
    })
    .filter(Boolean);
}

function getFailedConcepts(failedQuestions) {
  const conceptMap = new Map();

  failedQuestions.forEach((question) => {
    const concepts = question.concepts && question.concepts.length > 0 ? question.concepts : ['Uncategorized'];

    concepts.forEach((concept) => {
      const conceptName = concept || 'Uncategorized';
      const current = conceptMap.get(conceptName) || {
        name: conceptName,
        failedQuestionCount: 0,
        failedStepCount: 0
      };

      current.failedQuestionCount += 1;
      current.failedStepCount += question.failedValidationSteps.length;
      conceptMap.set(conceptName, current);
    });
  });

  return Array.from(conceptMap.values())
    .sort((a, b) => b.failedStepCount - a.failedStepCount || b.failedQuestionCount - a.failedQuestionCount);
}

function getFlatFailedValidationSteps(failedQuestions) {
  return failedQuestions.flatMap((question) => (
    question.failedValidationSteps.map((step) => ({
      questionId: question.id,
      questionTitle: question.questionTitle,
      concepts: question.concepts,
      id: step.id,
      description: step.description,
      weightage: step.weightage
    }))
  ));
}

function getDurationUsedSeconds(examInfo, result) {
  const startTime = examInfo.events?.examStartTime;
  const endTime = result.completedAt || examInfo.events?.examEndTime;

  if (!startTime || !endTime) {
    return null;
  }

  const durationMs = new Date(endTime) - new Date(startTime);
  if (!Number.isFinite(durationMs) || durationMs < 0) {
    return null;
  }

  return Math.round(durationMs / 1000);
}

// Aggregate earned/possible marks per blueprint domain using the
// concept→domain keyword mapping. Unmatched questions land in "unmapped".
function getDomainBreakdown(certificationCode, evaluationResults) {
  if (!certificationCode) {
    return [];
  }

  const domainMap = new Map();

  (evaluationResults || []).forEach((questionResult) => {
    const domainId = certificationCatalog.mapConceptsToDomain(
      certificationCode,
      questionResult.concepts || []
    );

    const current = domainMap.get(domainId) || {
      domainId,
      domainName: certificationCatalog.getDomainName(certificationCode, domainId),
      earned: 0,
      possible: 0,
      questionCount: 0
    };

    current.earned += getQuestionScore(questionResult);
    current.possible += getQuestionPossibleScore(questionResult);
    current.questionCount += 1;
    domainMap.set(domainId, current);
  });

  return Array.from(domainMap.values())
    .sort((a, b) => b.possible - a.possible || a.domainName.localeCompare(b.domainName));
}

function buildAttemptRecord(examId, examInfo, result) {
  const percentageScore = Number(result.percentageScore) || 0;
  const failedQuestions = getFailedQuestions(result.evaluationResults);
  const failedConcepts = getFailedConcepts(failedQuestions);
  const failedValidationSteps = getFlatFailedValidationSteps(failedQuestions);

  const category = examInfo.category || 'Uncategorized';
  const certification = certificationCatalog.getCertification(category);
  const certificationCode = certification ? certification.code : null;

  return {
    schemaVersion: HISTORY_VERSION,
    mode: examInfo.mode || 'timed',
    durationUsedSeconds: getDurationUsedSeconds(examInfo, result),
    certificationCode,
    blueprintVersion: certification?.blueprint?.version || null,
    domainBreakdown: getDomainBreakdown(certificationCode, result.evaluationResults),
    attemptId: randomUUID(),
    examSessionId: examId,
    labId: examInfo.id || examInfo.config?.lab || '',
    labName: examInfo.name || 'Unknown Exam',
    category: examInfo.category || 'Uncategorized',
    assetPath: examInfo.assetPath || '',
    difficulty: examInfo.difficulty || '',
    attemptedAt: examInfo.createdAt || result.completedAt || new Date().toISOString(),
    completedAt: result.completedAt || new Date().toISOString(),
    totalScore: Number(result.totalScore) || 0,
    totalPossibleScore: Number(result.totalPossibleScore) || 0,
    percentageScore,
    scoreLevel: result.rank || getScoreLevel(percentageScore),
    failedQuestions,
    failedConcepts,
    failedValidationSteps,
    rawResult: {
      stored: true,
      status: result.status || 'EVALUATED'
    }
  };
}

async function appendAttempt(examId, examInfo, result) {
  const attempt = buildAttemptRecord(examId, examInfo, result);

  return enqueueWrite(async () => {
    const history = await readHistory();
    await backupBeforeUpgrade(history.version);
    history.attempts.push(attempt);
    await writeHistoryAtomic({ version: HISTORY_VERSION, attempts: history.attempts });
    logger.info('Persisted exam attempt history', {
      examSessionId: examId,
      attemptId: attempt.attemptId
    });
    return attempt;
  });
}

/**
 * Delete a single attempt by attemptId.
 * Writes a timestamped backup of the whole file before removing the record.
 */
async function deleteAttempt(attemptId) {
  return enqueueWrite(async () => {
    const history = await readHistory();
    const index = history.attempts.findIndex((attempt) => attempt.attemptId === attemptId);

    if (index === -1) {
      return { deleted: false, reason: 'not-found' };
    }

    const backupPath = `${historyFilePath}.pre-delete.${Date.now()}.bak`;
    await fs.promises.copyFile(historyFilePath, backupPath);

    const [removed] = history.attempts.splice(index, 1);
    await writeHistoryAtomic({ version: HISTORY_VERSION, attempts: history.attempts });

    logger.info('Deleted exam attempt from history', { attemptId, backupPath });
    return { deleted: true, attempt: removed, backupPath };
  });
}

/**
 * Return the raw history document for export/backup.
 */
async function exportHistory() {
  const history = await readHistory();
  return {
    exportedAt: new Date().toISOString(),
    historyVersion: history.version,
    attempts: history.attempts
  };
}

function validateRestorePayload(payload) {
  if (!payload || typeof payload !== 'object') {
    return 'Restore payload must be a JSON object';
  }

  const attempts = payload.attempts;
  if (!Array.isArray(attempts)) {
    return 'Restore payload must contain an "attempts" array';
  }

  for (const attempt of attempts) {
    if (!attempt || typeof attempt !== 'object') {
      return 'Every attempt must be an object';
    }
    if (!attempt.attemptId || typeof attempt.attemptId !== 'string') {
      return 'Every attempt must have a string attemptId';
    }
    if (!attempt.completedAt || Number.isNaN(new Date(attempt.completedAt).getTime())) {
      return 'Every attempt must have a valid completedAt timestamp';
    }
    if (typeof attempt.percentageScore !== 'number') {
      return 'Every attempt must have a numeric percentageScore';
    }
  }

  return null;
}

/**
 * Replace the attempt history with an exported bundle.
 * Backs up the current file first; validation errors leave it untouched.
 */
async function restoreHistory(payload) {
  const validationError = validateRestorePayload(payload);
  if (validationError) {
    return { restored: false, error: validationError };
  }

  return enqueueWrite(async () => {
    await ensureHistoryFile();
    const backupPath = `${historyFilePath}.pre-restore.${Date.now()}.bak`;
    await fs.promises.copyFile(historyFilePath, backupPath);

    await writeHistoryAtomic({ version: HISTORY_VERSION, attempts: payload.attempts });

    logger.info('Restored attempt history from export bundle', {
      attemptCount: payload.attempts.length,
      backupPath
    });
    return { restored: true, attemptCount: payload.attempts.length, backupPath };
  });
}

/**
 * Reset the attempt history to an empty document after backing it up.
 */
async function resetHistory() {
  return enqueueWrite(async () => {
    await ensureHistoryFile();
    const backupPath = `${historyFilePath}.pre-reset.${Date.now()}.bak`;
    await fs.promises.copyFile(historyFilePath, backupPath);

    await writeHistoryAtomic({ version: HISTORY_VERSION, attempts: [] });

    logger.info('Reset attempt history', { backupPath });
    return { reset: true, backupPath };
  });
}

function filterAttempts(attempts, filters = {}) {
  return attempts.filter((attempt) => {
    if (filters.category && attempt.category !== filters.category) {
      return false;
    }

    if (filters.labId && attempt.labId !== filters.labId) {
      return false;
    }

    if (filters.labName && !attempt.labName.toLowerCase().includes(filters.labName.toLowerCase())) {
      return false;
    }

    if (filters.failedConcept) {
      const failedConcept = filters.failedConcept.toLowerCase();
      const hasConcept = (attempt.failedConcepts || [])
        .some((concept) => concept.name.toLowerCase() === failedConcept);
      if (!hasConcept) {
        return false;
      }
    }

    if (filters.from && new Date(attempt.completedAt) < new Date(filters.from)) {
      return false;
    }

    if (filters.to && new Date(attempt.completedAt) > new Date(filters.to)) {
      return false;
    }

    return true;
  });
}

function countBy(items, getKey) {
  const counts = new Map();

  items.forEach((item) => {
    const key = getKey(item);
    if (!key) {
      return;
    }
    counts.set(key, (counts.get(key) || 0) + 1);
  });

  return Array.from(counts.entries())
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
}

function getImprovementTrend(attempts) {
  const byLab = new Map();

  attempts.forEach((attempt) => {
    const key = attempt.labId || attempt.labName;
    const entries = byLab.get(key) || [];
    entries.push(attempt);
    byLab.set(key, entries);
  });

  return Array.from(byLab.values())
    .filter((entries) => entries.length > 1)
    .map((entries) => {
      const sorted = entries.sort((a, b) => new Date(a.completedAt) - new Date(b.completedAt));
      const previous = sorted[sorted.length - 2];
      const latest = sorted[sorted.length - 1];
      return {
        labId: latest.labId,
        labName: latest.labName,
        previousPercentage: previous.percentageScore,
        latestPercentage: latest.percentageScore,
        delta: latest.percentageScore - previous.percentageScore
      };
    })
    .sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));
}

function buildSummary(attempts) {
  const failedConceptEntries = attempts.flatMap((attempt) => (
    (attempt.failedConcepts || []).map((concept) => concept.name)
  ));

  const failedQuestionEntries = attempts.flatMap((attempt) => (
    (attempt.failedQuestions || []).map((question) => `${attempt.labName} - Question ${question.id}`)
  ));

  const latestFailedAttempt = [...attempts]
    .filter((attempt) => (attempt.failedQuestions || []).length > 0)
    .sort((a, b) => new Date(b.completedAt) - new Date(a.completedAt))[0] || null;

  return {
    totalAttempts: attempts.length,
    mostFailedConcepts: countBy(failedConceptEntries, (name) => name).slice(0, 10),
    mostFailedQuestions: countBy(failedQuestionEntries, (name) => name).slice(0, 10),
    latestFailedAttempt,
    improvementTrend: getImprovementTrend(attempts).slice(0, 10)
  };
}

function buildFilterOptions(attempts) {
  return {
    categories: Array.from(new Set(attempts.map((attempt) => attempt.category).filter(Boolean))).sort(),
    labs: Array.from(new Map(attempts.map((attempt) => [
      attempt.labId,
      { labId: attempt.labId, labName: attempt.labName }
    ])).values()).sort((a, b) => a.labName.localeCompare(b.labName)),
    failedConcepts: Array.from(new Set(attempts.flatMap((attempt) => (
      (attempt.failedConcepts || []).map((concept) => concept.name)
    )))).sort()
  };
}

async function getAttempts(filters = {}) {
  const history = await readHistory();
  const sortedAttempts = history.attempts
    .slice()
    .sort((a, b) => new Date(b.completedAt) - new Date(a.completedAt));
  const filteredAttempts = filterAttempts(sortedAttempts, filters);

  return {
    version: history.version,
    attempts: filteredAttempts,
    summary: buildSummary(filteredAttempts),
    filters: buildFilterOptions(sortedAttempts),
    historyFile: historyFilePath
  };
}

module.exports = {
  appendAttempt,
  getAttempts,
  getHistoryFilePath,
  buildAttemptRecord,
  deleteAttempt,
  exportHistory,
  restoreHistory,
  resetHistory
};
