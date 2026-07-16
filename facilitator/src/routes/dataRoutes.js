const express = require('express');
const dataController = require('../controllers/dataController');

const router = express.Router();

/**
 * @route GET /api/v1/data/info
 * @desc Local data summary: history file, version, attempt count, telemetry state
 */
router.get('/info', dataController.getDataInfo);

/**
 * @route GET /api/v1/data/export
 * @desc Download the attempt history as a JSON backup bundle
 */
router.get('/export', dataController.exportData);

/**
 * @route POST /api/v1/data/restore
 * @desc Restore attempt history from an exported bundle (current file backed up first)
 */
router.post('/restore', dataController.restoreData);

/**
 * @route POST /api/v1/data/reset
 * @desc Reset attempt history to empty (requires {"confirm":"RESET"}; file backed up first)
 */
router.post('/reset', dataController.resetData);

module.exports = router;
