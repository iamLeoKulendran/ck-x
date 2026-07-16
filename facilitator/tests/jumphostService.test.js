/**
 * Tests for Jumphost Service
 *
 * These tests verify that the jumphost service can properly
 * set up, clean up, and evaluate exam environments.
 */

const jumphostService = require('../src/services/jumphostService');
const sshService = require('../src/services/sshService');
const redisClient = require('../src/utils/redisClient');
const remoteDesktopService = require('../src/services/remoteDesktopService');
const attemptHistoryService = require('../src/services/attemptHistoryService');

// Mock dependencies
jest.mock('../src/services/sshService');
jest.mock('../src/utils/redisClient');
jest.mock('../src/services/remoteDesktopService');
jest.mock('../src/services/metricService', () => ({
  sendMetrics: jest.fn().mockResolvedValue(null)
}));
jest.mock('../src/services/attemptHistoryService');

describe('Jumphost Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    remoteDesktopService.restartVncSession.mockResolvedValue({ success: true });
  });

  describe('setupExamEnvironment', () => {
    it('should update exam status to PREPARING, restart VNC, execute the prepare command, and update status to READY on success', async () => {
      sshService.executeCommand.mockResolvedValueOnce({
        exitCode: 0,
        stdout: 'Environment prepared successfully',
        stderr: ''
      });

      const result = await jumphostService.setupExamEnvironment('test-exam-id', 2);

      expect(remoteDesktopService.restartVncSession).toHaveBeenCalledTimes(1);

      expect(redisClient.persistExamStatus).toHaveBeenCalledTimes(2);
      expect(redisClient.persistExamStatus).toHaveBeenNthCalledWith(1, 'test-exam-id', 'PREPARING');
      expect(redisClient.persistExamStatus).toHaveBeenNthCalledWith(2, 'test-exam-id', 'READY');

      expect(sshService.executeCommand).toHaveBeenCalledWith('prepare-exam-env 2 test-exam-id');

      expect(result).toEqual({
        success: true,
        message: 'Exam environment prepared successfully',
        details: {
          stdout: 'Environment prepared successfully'
        }
      });
    });

    it('should update exam status to PREPARATION_FAILED when the prepare command fails', async () => {
      sshService.executeCommand.mockResolvedValueOnce({
        exitCode: 1,
        stdout: '',
        stderr: 'Failed to prepare environment'
      });

      const result = await jumphostService.setupExamEnvironment('test-exam-id', 1);

      expect(redisClient.persistExamStatus).toHaveBeenNthCalledWith(1, 'test-exam-id', 'PREPARING');
      expect(redisClient.persistExamStatus).toHaveBeenNthCalledWith(2, 'test-exam-id', 'PREPARATION_FAILED');

      expect(result).toEqual({
        success: false,
        error: 'Failed to prepare exam environment',
        details: {
          stdout: '',
          stderr: 'Failed to prepare environment',
          exitCode: 1
        }
      });
    });

    it('should update exam status to PREPARATION_FAILED when an unexpected error occurs', async () => {
      sshService.executeCommand.mockRejectedValueOnce(new Error('SSH connection refused'));

      const result = await jumphostService.setupExamEnvironment('test-exam-id', 1);

      expect(redisClient.persistExamStatus).toHaveBeenLastCalledWith('test-exam-id', 'PREPARATION_FAILED');
      expect(result).toEqual({
        success: false,
        error: 'Error preparing exam environment',
        message: 'SSH connection refused'
      });
    });
  });

  describe('cleanupExamEnvironment', () => {
    it('should update exam status to CLEANING_UP, execute the cleanup command, and update status to COMPLETED on success', async () => {
      sshService.executeCommand.mockResolvedValueOnce({
        exitCode: 0,
        stdout: 'Environment cleaned up successfully',
        stderr: ''
      });

      const result = await jumphostService.cleanupExamEnvironment('test-exam-id');

      expect(redisClient.persistExamStatus).toHaveBeenNthCalledWith(1, 'test-exam-id', 'CLEANING_UP');
      expect(redisClient.persistExamStatus).toHaveBeenNthCalledWith(2, 'test-exam-id', 'COMPLETED');

      expect(sshService.executeCommand).toHaveBeenCalledWith('cleanup-exam-env');

      expect(result).toEqual({
        success: true,
        message: 'Exam environment cleaned up successfully',
        details: {
          stdout: 'Environment cleaned up successfully'
        }
      });
    });

    it('should update exam status to CLEANUP_FAILED when the cleanup command fails', async () => {
      sshService.executeCommand.mockResolvedValueOnce({
        exitCode: 1,
        stdout: '',
        stderr: 'Failed to clean up environment'
      });

      const result = await jumphostService.cleanupExamEnvironment('test-exam-id');

      expect(redisClient.persistExamStatus).toHaveBeenNthCalledWith(2, 'test-exam-id', 'CLEANUP_FAILED');

      expect(result).toEqual({
        success: false,
        error: 'Failed to clean up exam environment',
        details: {
          stdout: '',
          stderr: 'Failed to clean up environment',
          exitCode: 1
        }
      });
    });
  });

  describe('evaluateExamOnJumphost', () => {
    const questions = [
      {
        id: '1',
        namespace: 'ns-a',
        question: 'Fix the deployment',
        concepts: ['deployments'],
        verification: [
          {
            id: '1',
            description: 'deployment is ready',
            verificationScriptFile: 'q1_s1_validate.sh',
            weightage: 6
          },
          {
            id: '2',
            description: 'service routes traffic',
            verificationScriptFile: 'q1_s2_validate.sh',
            weightage: 4
          }
        ]
      }
    ];

    it('should score passed and failed verifications, persist the result, append attempt history, and set status EVALUATED', async () => {
      sshService.executeCommand
        .mockResolvedValueOnce({ exitCode: 0, stdout: 'ok', stderr: '' })
        .mockResolvedValueOnce({ exitCode: 1, stdout: '', stderr: 'not found' });
      redisClient.getExamInfo.mockResolvedValueOnce({ id: 'lab-1', category: 'CKA' });

      const result = await jumphostService.evaluateExamOnJumphost('test-exam-id', questions);

      expect(result.success).toBe(true);
      expect(result.data.totalScore).toBe(6);
      expect(result.data.totalPossibleScore).toBe(10);
      expect(result.data.percentageScore).toBe(60);
      expect(result.data.rank).toBe('medium');
      expect(result.data.evaluationResults[0].verificationResults).toEqual([
        expect.objectContaining({ id: '1', validAnswer: true, score: 6 }),
        expect.objectContaining({ id: '2', validAnswer: false, score: 0 })
      ]);

      expect(redisClient.persistExamResult).toHaveBeenCalledWith('test-exam-id', expect.objectContaining({
        status: 'EVALUATED',
        totalScore: 6
      }));
      expect(attemptHistoryService.appendAttempt).toHaveBeenCalledTimes(1);
      expect(redisClient.updateExamStatus).toHaveBeenCalledWith('test-exam-id', 'EVALUATED');
    });

    it('should still evaluate successfully when attempt history persistence fails', async () => {
      sshService.executeCommand
        .mockResolvedValueOnce({ exitCode: 0, stdout: 'ok', stderr: '' })
        .mockResolvedValueOnce({ exitCode: 0, stdout: 'ok', stderr: '' });
      redisClient.getExamInfo.mockResolvedValueOnce({ id: 'lab-1', category: 'CKA' });
      attemptHistoryService.appendAttempt.mockRejectedValueOnce(new Error('disk full'));

      const result = await jumphostService.evaluateExamOnJumphost('test-exam-id', questions);

      expect(result.success).toBe(true);
      expect(redisClient.updateExamStatus).toHaveBeenCalledWith('test-exam-id', 'EVALUATED');
    });
  });
});
