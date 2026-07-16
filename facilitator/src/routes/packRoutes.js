const express = require('express');
const packController = require('../controllers/packController');

const router = express.Router();

/**
 * @route GET /api/v1/packs
 * @desc List all registered labs as packs (built-in and imported)
 */
router.get('/', packController.listPacks);

/**
 * @route GET /api/v1/packs/:labId/export
 * @desc Download a lab as a portable JSON pack bundle
 */
router.get('/:labId/export', packController.exportPack);

/**
 * @route POST /api/v1/packs/import?validateOnly=true|false
 * @desc Validate and import a pack bundle. Performance-pack scripts run only
 *       inside the exam sandbox, never on the host or at import time.
 */
router.post('/import', packController.importPack);

/**
 * @route DELETE /api/v1/packs/:labId
 * @desc Delete an imported pack (built-in labs cannot be deleted via API)
 */
router.delete('/:labId', packController.deletePack);

module.exports = router;
