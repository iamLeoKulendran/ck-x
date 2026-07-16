const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

/**
 * Get all certification profiles (blueprint versions, domains, weights)
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getCertifications(req, res) {
  logger.info('Received request to get certification profiles');

  try {
    const certificationsFilePath = path.join(process.cwd(), 'assets', 'certifications.json');

    if (!fs.existsSync(certificationsFilePath)) {
      logger.error(`Certifications file not found at path: ${certificationsFilePath}`);
      return res.status(500).json({
        error: 'Certifications data not available',
        message: 'Could not find certifications data file'
      });
    }

    const certificationsData = fs.readFileSync(certificationsFilePath, 'utf8');
    const certifications = JSON.parse(certificationsData);

    logger.info(`Successfully retrieved ${certifications.certifications ? certifications.certifications.length : 0} certification profiles`);

    return res.status(200).json(certifications);
  } catch (error) {
    logger.error('Error reading certifications data', { error: error.message });
    return res.status(500).json({
      error: 'Failed to retrieve certifications data',
      message: error.message
    });
  }
}

module.exports = {
  getCertifications
};
