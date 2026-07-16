const express = require('express');
const mistakeController = require('../controllers/mistakeController');

const router = express.Router();

/**
 * @route GET /api/v1/mistakes
 * @desc List mistakes with derived resolved state, retest queue, and counts
 */
router.get('/', mistakeController.listMistakes);

/**
 * @route POST /api/v1/mistakes
 * @desc Capture a mistake from an attempt/question (never marked corrected at capture)
 */
router.post('/', mistakeController.createMistake);

/**
 * @route PATCH /api/v1/mistakes/:mistakeId/correction
 * @desc Update the correction status/note for a mistake
 */
router.patch('/:mistakeId/correction', mistakeController.updateCorrection);

/**
 * @route POST /api/v1/mistakes/:mistakeId/retests
 * @desc Schedule a delayed retest for a mistake
 */
router.post('/:mistakeId/retests', mistakeController.scheduleRetest);

/**
 * @route PATCH /api/v1/mistakes/:mistakeId/retests/:retestId
 * @desc Record a retest outcome (passed/failed)
 */
router.patch('/:mistakeId/retests/:retestId', mistakeController.recordRetestResult);

/**
 * @route DELETE /api/v1/mistakes/:mistakeId
 * @desc Delete a mistake record
 */
router.delete('/:mistakeId', mistakeController.deleteMistake);

module.exports = router;
