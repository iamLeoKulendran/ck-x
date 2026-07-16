/**
 * MCQ Service
 *
 * Deterministic server-side scoring for multiple-choice exams (KCNA/KCSA
 * style). The answer key lives only on the server (assessment.json); the
 * questions endpoint strips it, and this service compares submitted option
 * indexes against it at evaluation time. Results reuse the same shape the
 * jumphost evaluation produces so results/history/analytics work unchanged.
 */

const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');
const redisClient = require('../utils/redisClient');
const attemptHistoryService = require('./attemptHistoryService');

function loadAssessmentWithKeys(examInfo) {
  const assetPath = examInfo.assetPath;
  if (!assetPath) {
    throw new Error('Asset path not defined in exam info');
  }

  const questionsFile = examInfo.config?.questions || 'assessment.json';
  const fullPath = path.join(process.cwd(), assetPath, questionsFile);
  const parsed = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
  return parsed.questions || [];
}

function normalizeIndexes(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  // Note: Number(null) is 0, so nullish entries must be dropped BEFORE
  // conversion or they would silently select option 0
  return [...new Set(
    value
      .filter((entry) => entry !== null && entry !== undefined && entry !== '')
      .map((entry) => Number(entry))
      .filter(Number.isInteger)
  )].sort((a, b) => a - b);
}

/**
 * Score one MCQ question: full weightage when the selected option set is
 * exactly the correct set, otherwise zero. Deterministic by construction.
 */
function scoreQuestion(question, selectedIndexes) {
  const correct = normalizeIndexes(question.correctOptionIndexes);
  const selected = normalizeIndexes(selectedIndexes);
  const isCorrect = correct.length > 0 &&
    correct.length === selected.length &&
    correct.every((value, index) => value === selected[index]);

  return { isCorrect, correct, selected };
}

async function evaluateMcqExam(examId, answers = {}) {
  const examInfo = await redisClient.getExamInfo(examId);
  if (!examInfo) {
    return { success: false, error: 'Not Found', message: 'Exam not found' };
  }

  if (examInfo.config?.examType !== 'mcq') {
    return { success: false, error: 'Invalid exam type', message: 'This exam is not a multiple-choice exam' };
  }

  try {
    const questions = loadAssessmentWithKeys(examInfo);
    const mcqQuestions = questions.filter((question) => question.type === 'multiple-choice');
    if (mcqQuestions.length === 0) {
      return { success: false, error: 'Invalid assessment', message: 'No multiple-choice questions found' };
    }

    let totalScore = 0;
    let totalPossibleScore = 0;

    const evaluationResults = mcqQuestions.map((question) => {
      const weightage = Number(question.weightage) || 0;
      totalPossibleScore += weightage;

      const submitted = answers[String(question.id)];
      const { isCorrect, correct, selected } = scoreQuestion(question, submitted);
      const score = isCorrect ? weightage : 0;
      totalScore += score;

      return {
        id: question.id,
        namespace: question.domain || '',
        question: question.question,
        concepts: question.concepts || [],
        // Post-evaluation detail: what was chosen vs. what was right
        selectedOptionIndexes: selected,
        correctOptionIndexes: correct,
        verificationResults: [{
          id: '1',
          description: selected.length === 0
            ? 'No answer selected'
            : 'Correct option(s) selected',
          validAnswer: isCorrect,
          weightage,
          score
        }]
      };
    });

    const percentageScore = totalPossibleScore > 0
      ? Math.round((totalScore / totalPossibleScore) * 100)
      : 0;

    let rank = 'low';
    if (percentageScore >= 80) {
      rank = 'high';
    } else if (percentageScore >= 60) {
      rank = 'medium';
    }

    const finalResult = {
      examId,
      status: 'EVALUATED',
      totalScore,
      totalPossibleScore,
      percentageScore,
      rank,
      evaluationResults,
      completedAt: new Date().toISOString()
    };

    await redisClient.persistExamResult(examId, finalResult);

    try {
      await attemptHistoryService.appendAttempt(examId, examInfo, finalResult);
    } catch (historyError) {
      logger.error('Failed to persist MCQ attempt history', { examId, error: historyError.message });
    }

    await redisClient.updateExamStatus(examId, 'EVALUATED');
    logger.info(`MCQ exam ${examId} evaluated: ${percentageScore}%`);

    return { success: true, data: finalResult };
  } catch (error) {
    logger.error(`Error evaluating MCQ exam ${examId}`, { error: error.message });
    await redisClient.updateExamStatus(examId, 'EVALUATION_FAILED');
    return { success: false, error: 'Evaluation failed', message: error.message };
  }
}

module.exports = {
  evaluateMcqExam,
  scoreQuestion
};
