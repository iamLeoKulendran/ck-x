const express = require('express');
const analyticsController = require('../controllers/analyticsController');

const router = express.Router();

/**
 * @route GET /api/v1/analytics
 * @desc Per-certification analytics derived from stored attempts
 * @access Public
 */
router.get('/', analyticsController.getAnalytics);

module.exports = router;
