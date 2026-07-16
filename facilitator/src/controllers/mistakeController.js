const mistakeService = require('../services/mistakeService');
const logger = require('../utils/logger');

async function listMistakes(req, res) {
  try {
    const result = await mistakeService.listMistakes({
      category: req.query.category,
      resolved: req.query.resolved,
      certificationCode: req.query.certificationCode
    });
    return res.status(200).json({ success: true, data: result });
  } catch (error) {
    logger.error('Error listing mistakes', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to list mistakes', message: error.message });
  }
}

async function createMistake(req, res) {
  try {
    const result = await mistakeService.createMistake(req.body);

    if (result.duplicate) {
      return res.status(200).json({
        success: true,
        data: { duplicate: true, mistake: result.mistake, message: 'A mistake for this attempt and question already exists' }
      });
    }
    if (!result.created) {
      return res.status(400).json({ success: false, error: 'Invalid mistake payload', message: result.error });
    }

    return res.status(201).json({ success: true, data: { mistake: result.mistake } });
  } catch (error) {
    logger.error('Error creating mistake', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to create mistake', message: error.message });
  }
}

async function updateCorrection(req, res) {
  try {
    const result = await mistakeService.updateCorrection(req.params.mistakeId, req.body);
    if (!result.updated) {
      const status = result.error === 'not-found' ? 404 : 400;
      return res.status(status).json({ success: false, error: result.error });
    }
    return res.status(200).json({ success: true, data: { mistake: result.mistake } });
  } catch (error) {
    logger.error('Error updating correction', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to update correction', message: error.message });
  }
}

async function scheduleRetest(req, res) {
  try {
    const result = await mistakeService.scheduleRetest(req.params.mistakeId, req.body || {});
    if (!result.scheduled) {
      return res.status(404).json({ success: false, error: result.error });
    }
    return res.status(201).json({ success: true, data: { mistake: result.mistake, retest: result.retest } });
  } catch (error) {
    logger.error('Error scheduling retest', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to schedule retest', message: error.message });
  }
}

async function recordRetestResult(req, res) {
  try {
    const result = await mistakeService.recordRetestResult(req.params.mistakeId, req.params.retestId, req.body);
    if (!result.recorded) {
      const status = result.error && result.error.includes('not-found') ? 404 : 400;
      return res.status(status).json({ success: false, error: result.error });
    }
    return res.status(200).json({ success: true, data: { mistake: result.mistake } });
  } catch (error) {
    logger.error('Error recording retest result', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to record retest result', message: error.message });
  }
}

async function deleteMistake(req, res) {
  try {
    const result = await mistakeService.deleteMistake(req.params.mistakeId);
    if (!result.deleted) {
      return res.status(404).json({ success: false, error: result.error });
    }
    return res.status(200).json({ success: true, data: { message: 'Mistake deleted' } });
  } catch (error) {
    logger.error('Error deleting mistake', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to delete mistake', message: error.message });
  }
}

module.exports = {
  listMistakes,
  createMistake,
  updateCorrection,
  scheduleRetest,
  recordRetestResult,
  deleteMistake
};
