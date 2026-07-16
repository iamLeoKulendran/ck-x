const analyticsService = require('../services/analyticsService');
const logger = require('../utils/logger');

/**
 * Get analytics derived from the persisted attempt history
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getAnalytics(req, res) {
  logger.info('Received request to get analytics');

  try {
    const analytics = await analyticsService.getAnalytics();
    return res.status(200).json({
      success: true,
      data: analytics
    });
  } catch (error) {
    logger.error('Error computing analytics', { error: error.message });
    return res.status(500).json({
      success: false,
      error: 'Failed to compute analytics',
      message: error.message
    });
  }
}

module.exports = {
  getAnalytics
};
