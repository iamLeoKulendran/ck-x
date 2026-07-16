/**
 * Tests for MCQ scoring
 */

const mcqService = require('../src/services/mcqService');

describe('MCQ scoreQuestion', () => {
  const singleAnswer = { correctOptionIndexes: [2] };
  const multiAnswer = { correctOptionIndexes: [0, 2, 3] };

  it('awards a single-answer question only for the exact correct option', () => {
    expect(mcqService.scoreQuestion(singleAnswer, [2]).isCorrect).toBe(true);
    expect(mcqService.scoreQuestion(singleAnswer, [1]).isCorrect).toBe(false);
    expect(mcqService.scoreQuestion(singleAnswer, []).isCorrect).toBe(false);
    expect(mcqService.scoreQuestion(singleAnswer, undefined).isCorrect).toBe(false);
  });

  it('requires the exact option set for multi-select questions (no partial credit)', () => {
    expect(mcqService.scoreQuestion(multiAnswer, [0, 2, 3]).isCorrect).toBe(true);
    expect(mcqService.scoreQuestion(multiAnswer, [3, 0, 2]).isCorrect).toBe(true); // order-insensitive
    expect(mcqService.scoreQuestion(multiAnswer, [0, 2]).isCorrect).toBe(false);
    expect(mcqService.scoreQuestion(multiAnswer, [0, 1, 2, 3]).isCorrect).toBe(false);
  });

  it('deduplicates and sanitizes submitted indexes', () => {
    expect(mcqService.scoreQuestion(singleAnswer, [2, 2, '2']).isCorrect).toBe(true);
    expect(mcqService.scoreQuestion(singleAnswer, ['a', null, 2]).isCorrect).toBe(true);
  });

  it('never marks a question with no answer key as correct', () => {
    expect(mcqService.scoreQuestion({ correctOptionIndexes: [] }, []).isCorrect).toBe(false);
    expect(mcqService.scoreQuestion({}, [0]).isCorrect).toBe(false);
  });
});

describe('Sample MCQ packs', () => {
  const fs = require('fs');
  const path = require('path');

  ['kcna/001', 'kcsa/001'].forEach((packPath) => {
    describe(packPath, () => {
      const dir = path.join(__dirname, '..', 'assets', 'exams', packPath);
      const assessment = JSON.parse(fs.readFileSync(path.join(dir, 'assessment.json'), 'utf8'));
      const config = JSON.parse(fs.readFileSync(path.join(dir, 'config.json'), 'utf8'));

      it('is a valid MCQ pack with weights summing to totalMarks', () => {
        expect(config.examType).toBe('mcq');
        const total = assessment.questions.reduce((sum, question) => sum + question.weightage, 0);
        expect(total).toBe(config.totalMarks);
      });

      it('every question has type, options, a valid answer key, and an explanation', () => {
        assessment.questions.forEach((question) => {
          expect(question.type).toBe('multiple-choice');
          expect(question.options.length).toBeGreaterThanOrEqual(3);
          expect(question.correctOptionIndexes.length).toBeGreaterThan(0);
          question.correctOptionIndexes.forEach((index) => {
            expect(index).toBeGreaterThanOrEqual(0);
            expect(index).toBeLessThan(question.options.length);
          });
          expect(typeof question.explanation).toBe('string');
          expect(question.domain).toBeTruthy();
        });
      });
    });
  });
});
