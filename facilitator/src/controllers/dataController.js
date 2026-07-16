/**
 * Data Controller
 *
 * Local-first data safety endpoints: export the attempt history as a
 * downloadable JSON bundle, restore from a previously exported bundle,
 * and reset local data. Restore and reset always back up the current
 * file before writing.
 */

const attemptHistoryService = require('../services/attemptHistoryService');
const mistakeService = require('../services/mistakeService');
const logger = require('../utils/logger');

async function exportData(req, res) {
  logger.info('Received request to export local data');

  try {
    const bundle = await attemptHistoryService.exportHistory();
    bundle.mistakes = await mistakeService.exportMistakes();
    const fileName = `ckx-data-export-${new Date().toISOString().slice(0, 10)}.json`;

    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
    res.setHeader('Content-Type', 'application/json');
    return res.status(200).send(JSON.stringify(bundle, null, 2));
  } catch (error) {
    logger.error('Error exporting local data', { error: error.message });
    return res.status(500).json({
      success: false,
      error: 'Failed to export data',
      message: error.message
    });
  }
}

async function restoreData(req, res) {
  logger.info('Received request to restore local data');

  try {
    // Validate the optional mistakes section BEFORE restoring anything, so a
    // bad section cannot leave history restored but mistakes rejected
    if (req.body && req.body.mistakes && !Array.isArray(req.body.mistakes.mistakes)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid mistakes section in restore bundle',
        message: 'mistakes must contain a "mistakes" array'
      });
    }

    const result = await attemptHistoryService.restoreHistory(req.body);

    if (!result.restored) {
      return res.status(400).json({
        success: false,
        error: 'Invalid restore bundle',
        message: result.error
      });
    }

    // Older bundles have no mistakes section; restore it only when present
    let mistakeCount = null;
    if (req.body.mistakes) {
      const mistakeResult = await mistakeService.restoreMistakes(req.body.mistakes);
      if (!mistakeResult.restored) {
        return res.status(400).json({
          success: false,
          error: 'Invalid mistakes section in restore bundle',
          message: mistakeResult.error
        });
      }
      mistakeCount = mistakeResult.mistakeCount;
    }

    return res.status(200).json({
      success: true,
      data: {
        attemptCount: result.attemptCount,
        mistakeCount,
        message: 'History restored; the previous file was backed up first'
      }
    });
  } catch (error) {
    logger.error('Error restoring local data', { error: error.message });
    return res.status(500).json({
      success: false,
      error: 'Failed to restore data',
      message: error.message
    });
  }
}

async function resetData(req, res) {
  logger.info('Received request to reset local data');

  // Require explicit confirmation in the body so a stray POST cannot wipe data
  if (!req.body || req.body.confirm !== 'RESET') {
    return res.status(400).json({
      success: false,
      error: 'Confirmation required',
      message: 'Send {"confirm": "RESET"} to reset the attempt history'
    });
  }

  try {
    await attemptHistoryService.resetHistory();
    return res.status(200).json({
      success: true,
      data: {
        message: 'Attempt history reset; the previous file was backed up first'
      }
    });
  } catch (error) {
    logger.error('Error resetting local data', { error: error.message });
    return res.status(500).json({
      success: false,
      error: 'Failed to reset data',
      message: error.message
    });
  }
}

async function getDataInfo(req, res) {
  try {
    const bundle = await attemptHistoryService.exportHistory();
    const mistakes = await mistakeService.exportMistakes();
    return res.status(200).json({
      success: true,
      data: {
        historyFile: attemptHistoryService.getHistoryFilePath(),
        historyVersion: bundle.historyVersion,
        attemptCount: bundle.attempts.length,
        mistakeCount: mistakes.mistakes.length,
        telemetryEnabled: process.env.TRACK_METRICS === 'true'
      }
    });
  } catch (error) {
    logger.error('Error reading local data info', { error: error.message });
    return res.status(500).json({
      success: false,
      error: 'Failed to read data info',
      message: error.message
    });
  }
}

module.exports = {
  exportData,
  restoreData,
  resetData,
  getDataInfo
};
