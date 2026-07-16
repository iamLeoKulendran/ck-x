const packService = require('../services/packService');
const logger = require('../utils/logger');

async function listPacks(req, res) {
  try {
    const packs = await packService.listPacks();
    return res.status(200).json({ success: true, data: { packs } });
  } catch (error) {
    logger.error('Error listing packs', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to list packs', message: error.message });
  }
}

async function exportPack(req, res) {
  try {
    const result = await packService.exportPack(req.params.labId);
    if (!result.success) {
      const status = result.error === 'not-found' ? 404 : 500;
      return res.status(status).json({ success: false, error: result.error, message: result.message });
    }

    const fileName = `ckx-pack-${req.params.labId}.json`;
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
    res.setHeader('Content-Type', 'application/json');
    return res.status(200).send(JSON.stringify(result.bundle, null, 2));
  } catch (error) {
    logger.error('Error exporting pack', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to export pack', message: error.message });
  }
}

async function importPack(req, res) {
  try {
    const validateOnly = req.query.validateOnly === 'true';
    const result = await packService.importPack(req.body, { validateOnly });

    if (validateOnly) {
      return res.status(200).json({
        success: true,
        data: { valid: result.valid === true || result.imported === true, errors: result.errors, examType: result.examType }
      });
    }

    if (!result.imported) {
      return res.status(result.duplicate ? 409 : 400).json({
        success: false,
        error: result.duplicate ? 'Duplicate pack id' : 'Invalid pack bundle',
        errors: result.errors
      });
    }

    return res.status(201).json({ success: true, data: result });
  } catch (error) {
    logger.error('Error importing pack', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to import pack', message: error.message });
  }
}

async function deletePack(req, res) {
  try {
    const result = await packService.deleteImportedPack(req.params.labId);
    if (!result.deleted) {
      const status = result.error === 'not-found' ? 404 : 400;
      return res.status(status).json({ success: false, error: result.error, message: result.message });
    }
    return res.status(200).json({ success: true, data: { message: 'Pack deleted' } });
  } catch (error) {
    logger.error('Error deleting pack', { error: error.message });
    return res.status(500).json({ success: false, error: 'Failed to delete pack', message: error.message });
  }
}

module.exports = {
  listPacks,
  exportPack,
  importPack,
  deletePack
};
