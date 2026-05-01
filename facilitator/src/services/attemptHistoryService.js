const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const logger = require('../utils/logger');

const HISTORY_VERSION = 1;
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

  return {
    version: history.version || HISTORY_VERSION,
    attempts: history.attempts
  };
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

function buildAttemptRecord(examId, examInfo, result) {
  const percentageScore = Number(result.percentageScore) || 0;
  const failedQuestions = getFailedQuestions(result.evaluationResults);
  const failedConcepts = getFailedConcepts(failedQuestions);
  const failedValidationSteps = getFlatFailedValidationSteps(failedQuestions);

  return {
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
    history.attempts.push(attempt);
    await writeHistoryAtomic(history);
    logger.info('Persisted exam attempt history', {
      examSessionId: examId,
      attemptId: attempt.attemptId
    });
    return attempt;
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
  buildAttemptRecord
};
