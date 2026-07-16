/**
 * Pack Service
 *
 * Question-pack portability: export any registered lab as a single JSON
 * bundle, validate and import community bundles, and remove imported packs.
 *
 * Trust boundary (docs/CK_X_PRODUCT_AND_IMPLEMENTATION_PLAN.md §12):
 * - Performance packs contain bash that will execute inside the jumphost/k3d
 *   sandbox when an exam runs. They are NEVER executed at import time and
 *   NEVER on the host. The UI must warn before import.
 * - MCQ packs are data-only; the schema rejects any scripts.
 * - All file names are validated against traversal; imports land only under
 *   assets/exams/imported/<packId>/.
 */

const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const logger = require('../utils/logger');

const PACK_FORMAT_VERSION = 1;
const EXAMS_DIR = process.env.EXAMS_DIR || path.join(process.cwd(), 'assets', 'exams');
const IMPORTED_DIR_NAME = 'imported';

const MAX_BUNDLE_BYTES = 5 * 1024 * 1024; // 5 MB serialized bundle
const MAX_SCRIPT_BYTES = 100 * 1024; // 100 KB per script
const SAFE_ID_PATTERN = /^[a-z0-9][a-z0-9-]{1,63}$/;
const SAFE_FILENAME_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const KNOWN_CATEGORIES = ['CKA', 'CKAD', 'CKS', 'KCNA', 'KCSA', 'Other'];

function labsJsonPath() {
  return path.join(EXAMS_DIR, 'labs.json');
}

function readLabsRegistry() {
  const parsed = JSON.parse(fs.readFileSync(labsJsonPath(), 'utf8'));
  if (!parsed || !Array.isArray(parsed.labs)) {
    throw new Error('labs.json has an invalid format');
  }
  return parsed;
}

async function backupRegistry() {
  const backupPath = `${labsJsonPath()}.pre-import.${Date.now()}.bak`;
  await fs.promises.copyFile(labsJsonPath(), backupPath);
  return backupPath;
}

function readJsonIfExists(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function readTextIfExists(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }
  return fs.readFileSync(filePath, 'utf8');
}

async function listPacks() {
  const registry = readLabsRegistry();

  return registry.labs.map((lab) => {
    const packDir = path.join(EXAMS_DIR, ...lab.assetPath.replace(/^assets\/exams\//, '').split('/'));
    const config = readJsonIfExists(path.join(packDir, 'config.json'));
    const assessment = readJsonIfExists(path.join(packDir, config?.questions || 'assessment.json'));

    return {
      id: lab.id,
      name: lab.name,
      category: lab.category,
      difficulty: lab.difficulty || '',
      examDurationInMinutes: lab.examDurationInMinutes || null,
      examType: config?.examType === 'mcq' ? 'mcq' : 'performance',
      questionCount: assessment?.questions?.length ?? null,
      totalMarks: config?.totalMarks ?? null,
      imported: lab.assetPath.startsWith(`assets/exams/${IMPORTED_DIR_NAME}/`),
      assetPath: lab.assetPath
    };
  });
}

async function exportPack(labId) {
  const registry = readLabsRegistry();
  const lab = registry.labs.find((entry) => entry.id === labId);
  if (!lab) {
    return { success: false, error: 'not-found' };
  }

  const packDir = path.join(EXAMS_DIR, ...lab.assetPath.replace(/^assets\/exams\//, '').split('/'));
  const config = readJsonIfExists(path.join(packDir, 'config.json'));
  const assessment = readJsonIfExists(path.join(packDir, config?.questions || 'assessment.json'));

  if (!config || !assessment) {
    return { success: false, error: 'incomplete-pack', message: 'config.json or assessment file missing' };
  }

  const answersFile = config.answers
    ? path.join(process.cwd(), config.answers)
    : path.join(packDir, 'answers.md');
  const answersMarkdown = readTextIfExists(answersFile) || readTextIfExists(path.join(packDir, 'answers.md'));

  const scripts = { setup: {}, validation: {} };
  ['setup', 'validation'].forEach((kind) => {
    const dir = path.join(packDir, 'scripts', kind);
    if (fs.existsSync(dir)) {
      fs.readdirSync(dir).forEach((file) => {
        scripts[kind][file] = fs.readFileSync(path.join(dir, file), 'utf8');
      });
    }
  });

  return {
    success: true,
    bundle: {
      packFormatVersion: PACK_FORMAT_VERSION,
      exportedAt: new Date().toISOString(),
      lab: { ...lab },
      config,
      assessment,
      answersMarkdown: answersMarkdown || '',
      scripts
    }
  };
}

function validateMcqAssessment(assessment, config, errors) {
  let totalWeight = 0;
  assessment.questions.forEach((question, index) => {
    const label = `question[${index}] (id ${question.id})`;
    if (question.type !== 'multiple-choice') {
      errors.push(`${label}: MCQ packs may only contain multiple-choice questions`);
      return;
    }
    if (!Array.isArray(question.options) || question.options.length < 2) {
      errors.push(`${label}: needs at least 2 options`);
    }
    if (!Array.isArray(question.correctOptionIndexes) || question.correctOptionIndexes.length === 0) {
      errors.push(`${label}: correctOptionIndexes must be a non-empty array`);
    } else if (Array.isArray(question.options)) {
      question.correctOptionIndexes.forEach((optionIndex) => {
        if (!Number.isInteger(optionIndex) || optionIndex < 0 || optionIndex >= question.options.length) {
          errors.push(`${label}: correct option index ${optionIndex} is out of range`);
        }
      });
    }
    totalWeight += Number(question.weightage) || 0;
  });

  const totalMarks = Number(config.totalMarks) || 100;
  if (totalWeight !== totalMarks) {
    errors.push(`Question weights sum to ${totalWeight}, expected totalMarks ${totalMarks}`);
  }
}

function validatePerformanceAssessment(assessment, config, scripts, errors) {
  let totalWeight = 0;

  assessment.questions.forEach((question, index) => {
    const label = `question[${index}] (id ${question.id})`;
    if (!Array.isArray(question.verification) || question.verification.length === 0) {
      errors.push(`${label}: performance questions need a verification array`);
      return;
    }
    question.verification.forEach((verification) => {
      totalWeight += Number(verification.weightage) || 0;
      const scriptFile = verification.verificationScriptFile;
      if (!scriptFile || !SAFE_FILENAME_PATTERN.test(scriptFile)) {
        errors.push(`${label}: verification script name "${scriptFile}" is missing or unsafe`);
      } else if (!scripts.validation[scriptFile]) {
        errors.push(`${label}: verification script "${scriptFile}" not included in bundle`);
      }
    });
  });

  const totalMarks = Number(config.totalMarks) || 100;
  if (totalWeight !== totalMarks) {
    errors.push(`Validation weightages sum to ${totalWeight}, expected totalMarks ${totalMarks}`);
  }

  if (Object.keys(scripts.setup).length === 0) {
    errors.push('Performance packs need at least one setup script');
  }
}

/**
 * Validate an import bundle. Returns { valid, errors, examType }.
 * Never executes any bundle content.
 */
function validateBundle(bundle) {
  const errors = [];

  if (!bundle || typeof bundle !== 'object') {
    return { valid: false, errors: ['Bundle must be a JSON object'] };
  }

  if (bundle.packFormatVersion !== PACK_FORMAT_VERSION) {
    errors.push(`packFormatVersion must be ${PACK_FORMAT_VERSION}`);
  }

  const serializedSize = Buffer.byteLength(JSON.stringify(bundle), 'utf8');
  if (serializedSize > MAX_BUNDLE_BYTES) {
    errors.push(`Bundle is ${serializedSize} bytes; maximum is ${MAX_BUNDLE_BYTES}`);
  }

  const lab = bundle.lab;
  if (!lab || typeof lab !== 'object') {
    errors.push('lab entry is required');
  } else {
    if (!lab.id || !SAFE_ID_PATTERN.test(lab.id)) {
      errors.push('lab.id must match ^[a-z0-9][a-z0-9-]{1,63}$');
    }
    if (!lab.name || typeof lab.name !== 'string') {
      errors.push('lab.name is required');
    }
    if (!KNOWN_CATEGORIES.includes(lab.category)) {
      errors.push(`lab.category must be one of: ${KNOWN_CATEGORIES.join(', ')}`);
    }
  }

  if (!bundle.config || typeof bundle.config !== 'object') {
    errors.push('config is required');
  }
  if (!bundle.assessment || !Array.isArray(bundle.assessment.questions) || bundle.assessment.questions.length === 0) {
    errors.push('assessment.questions must be a non-empty array');
  }

  const scripts = {
    setup: bundle.scripts?.setup && typeof bundle.scripts.setup === 'object' ? bundle.scripts.setup : {},
    validation: bundle.scripts?.validation && typeof bundle.scripts.validation === 'object' ? bundle.scripts.validation : {}
  };

  // Script file-name and size safety (both kinds)
  ['setup', 'validation'].forEach((kind) => {
    Object.entries(scripts[kind]).forEach(([fileName, content]) => {
      if (!SAFE_FILENAME_PATTERN.test(fileName)) {
        errors.push(`scripts.${kind}: unsafe file name "${fileName}"`);
      }
      if (typeof content !== 'string') {
        errors.push(`scripts.${kind}/${fileName}: content must be a string`);
      } else if (Buffer.byteLength(content, 'utf8') > MAX_SCRIPT_BYTES) {
        errors.push(`scripts.${kind}/${fileName}: exceeds ${MAX_SCRIPT_BYTES} bytes`);
      }
    });
  });

  const examType = bundle.config?.examType === 'mcq' ? 'mcq' : 'performance';

  if (errors.length === 0) {
    if (examType === 'mcq') {
      if (Object.keys(scripts.setup).length > 0 || Object.keys(scripts.validation).length > 0) {
        errors.push('MCQ packs are data-only: scripts are not allowed');
      }
      validateMcqAssessment(bundle.assessment, bundle.config, errors);
    } else {
      validatePerformanceAssessment(bundle.assessment, bundle.config, scripts, errors);
    }
  }

  return { valid: errors.length === 0, errors, examType };
}

function packageScriptsArchive(packDir) {
  return new Promise((resolve) => {
    execFile('tar', ['-czf', 'assets.tar.gz', 'scripts/'], { cwd: packDir }, (error) => {
      if (error) {
        logger.warn('Failed to package imported pack scripts; a facilitator restart will regenerate it', {
          packDir,
          error: error.message
        });
        resolve(false);
      } else {
        resolve(true);
      }
    });
  });
}

/**
 * Import a validated bundle. Set options.validateOnly to run validation
 * without writing anything (used by the builder for pre-flight checks).
 */
async function importPack(bundle, options = {}) {
  const validation = validateBundle(bundle);
  if (!validation.valid) {
    return { imported: false, errors: validation.errors };
  }

  const registry = readLabsRegistry();
  const duplicate = registry.labs.find((entry) => entry.id === bundle.lab.id);
  if (duplicate) {
    return {
      imported: false,
      duplicate: true,
      errors: [`A lab with id "${bundle.lab.id}" already exists. Change the pack id to import it alongside, or delete the existing pack first.`]
    };
  }

  if (options.validateOnly) {
    return { imported: false, valid: true, examType: validation.examType, errors: [] };
  }

  const packId = bundle.lab.id;
  const relativeAssetPath = `assets/exams/${IMPORTED_DIR_NAME}/${packId}`;
  const packDir = path.join(EXAMS_DIR, IMPORTED_DIR_NAME, packId);

  await fs.promises.mkdir(packDir, { recursive: true });

  // Rewrite paths the runtime reads from config: answers + questions stay inside the pack
  const config = {
    ...bundle.config,
    lab: packId,
    answers: `${relativeAssetPath}/answers.md`,
    questions: 'assessment.json'
  };

  await fs.promises.writeFile(path.join(packDir, 'config.json'), JSON.stringify(config, null, 2));
  await fs.promises.writeFile(path.join(packDir, 'assessment.json'), JSON.stringify(bundle.assessment, null, 2));
  await fs.promises.writeFile(path.join(packDir, 'answers.md'), bundle.answersMarkdown || '# Answers\n\nNot provided.\n');

  let scriptsPackaged = null;
  if (validation.examType === 'performance') {
    for (const kind of ['setup', 'validation']) {
      const dir = path.join(packDir, 'scripts', kind);
      await fs.promises.mkdir(dir, { recursive: true });
      for (const [fileName, content] of Object.entries(bundle.scripts[kind] || {})) {
        const filePath = path.join(dir, fileName);
        await fs.promises.writeFile(filePath, content);
        await fs.promises.chmod(filePath, 0o755);
      }
    }
    scriptsPackaged = await packageScriptsArchive(packDir);
  }

  const registryBackup = await backupRegistry();

  const labEntry = {
    id: packId,
    assetPath: relativeAssetPath,
    name: bundle.lab.name,
    category: bundle.lab.category,
    description: bundle.lab.description || 'Imported question pack.',
    warmUpTimeInSeconds: Number(bundle.lab.warmUpTimeInSeconds) || (validation.examType === 'mcq' ? 5 : 260),
    difficulty: bundle.lab.difficulty || 'Medium',
    examDurationInMinutes: Number(bundle.lab.examDurationInMinutes) || 60
  };
  if (bundle.lab.certificationCode) {
    labEntry.certificationCode = bundle.lab.certificationCode;
  }

  registry.labs.push(labEntry);
  await fs.promises.writeFile(labsJsonPath(), `${JSON.stringify(registry, null, 2)}\n`);

  logger.info('Imported question pack', { packId, examType: validation.examType, registryBackup });

  return {
    imported: true,
    packId,
    examType: validation.examType,
    scriptsPackaged,
    errors: []
  };
}

/**
 * Delete an imported pack (only packs under assets/exams/imported/ can be
 * deleted through the API; built-in labs stay file-managed).
 */
async function deleteImportedPack(labId) {
  const registry = readLabsRegistry();
  const index = registry.labs.findIndex((entry) => entry.id === labId);
  if (index === -1) {
    return { deleted: false, error: 'not-found' };
  }

  const lab = registry.labs[index];
  if (!lab.assetPath.startsWith(`assets/exams/${IMPORTED_DIR_NAME}/`)) {
    return { deleted: false, error: 'not-imported', message: 'Only imported packs can be deleted through the API' };
  }

  // Resolve and double-check the directory stays inside the imported area
  const packDir = path.resolve(EXAMS_DIR, IMPORTED_DIR_NAME, path.basename(lab.assetPath));
  if (!packDir.startsWith(path.resolve(EXAMS_DIR, IMPORTED_DIR_NAME))) {
    return { deleted: false, error: 'unsafe-path' };
  }

  await backupRegistry();
  registry.labs.splice(index, 1);
  await fs.promises.writeFile(labsJsonPath(), `${JSON.stringify(registry, null, 2)}\n`);
  await fs.promises.rm(packDir, { recursive: true, force: true });

  logger.info('Deleted imported pack', { labId });
  return { deleted: true };
}

module.exports = {
  listPacks,
  exportPack,
  importPack,
  deleteImportedPack,
  validateBundle,
  PACK_FORMAT_VERSION
};
