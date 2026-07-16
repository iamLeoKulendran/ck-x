const express = require('express');
const certificationController = require('../controllers/certificationController');

const router = express.Router();

/**
 * @route GET /api/v1/certifications
 * @desc Get all certification profiles with blueprint domains and weights
 * @access Public
 */
router.get('/', certificationController.getCertifications);

module.exports = router;
