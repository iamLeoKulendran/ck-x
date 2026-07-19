/**
 * Tests for exam question sanitization (getExamQuestions)
 */

jest.mock('../src/utils/redisClient', () => ({
  getExamStatus: jest.fn(),
  getExamInfo: jest.fn()
}));

const redisClient = require('../src/utils/redisClient');
const examService = require('../src/services/examService');

describe('getExamQuestions sanitization', () => {
  // Real MCQ pack: q4 is the known multi-answer question, the rest are single-answer
  const EXAM_ID = 'test-exam-sanitize';

  beforeEach(() => {
    redisClient.getExamStatus.mockResolvedValue('READY');
    redisClient.getExamInfo.mockResolvedValue({ assetPath: 'assets/exams/kcna/001' });
  });

  it('never exposes correctOptionIndexes or explanation', async () => {
    const result = await examService.getExamQuestions(EXAM_ID);
    expect(result.success).toBe(true);
    result.data.questions.forEach((question) => {
      expect(question).not.toHaveProperty('correctOptionIndexes');
      expect(question).not.toHaveProperty('explanation');
    });
  });

  it('marks a multi-answer question multiSelect: true without the answer key', async () => {
    const result = await examService.getExamQuestions(EXAM_ID);
    expect(result.success).toBe(true);
    const multi = result.data.questions.find((question) => question.id === '4');
    expect(multi.multiSelect).toBe(true);
    expect(multi).not.toHaveProperty('correctOptionIndexes');
    expect(multi).not.toHaveProperty('explanation');
  });

  it('marks single-answer questions multiSelect: false', async () => {
    const result = await examService.getExamQuestions(EXAM_ID);
    expect(result.success).toBe(true);
    result.data.questions
      .filter((question) => question.id !== '4')
      .forEach((question) => {
        expect(question.multiSelect).toBe(false);
      });
  });
});

describe('getExamQuestions sanitization edge cases', () => {
  const EXAM_ID = 'test-exam-edge';

  beforeEach(() => {
    redisClient.getExamStatus.mockResolvedValue('READY');
    redisClient.getExamInfo.mockResolvedValue({ assetPath: 'tests/fixtures/mcq-edge' });
  });

  it('strips answer-key fields from non-multiple-choice questions too', async () => {
    const result = await examService.getExamQuestions(EXAM_ID);
    expect(result.success).toBe(true);
    const perf = result.data.questions.find((question) => question.id === '1');
    expect(perf).not.toHaveProperty('correctOptionIndexes');
    expect(perf).not.toHaveProperty('explanation');
  });

  it('derives multiSelect strictly from the key, ignoring author-set values', async () => {
    const result = await examService.getExamQuestions(EXAM_ID);
    const noKey = result.data.questions.find((question) => question.id === '2');
    expect(noKey.multiSelect).toBe(false);
  });

  it('treats an empty answer key as single-select', async () => {
    const result = await examService.getExamQuestions(EXAM_ID);
    const emptyKey = result.data.questions.find((question) => question.id === '3');
    expect(emptyKey.multiSelect).toBe(false);
  });
});
