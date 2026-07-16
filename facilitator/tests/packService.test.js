/**
 * Tests for Pack Service: bundle validation, import/export round trip,
 * duplicate detection, and traversal/malicious-input rejection.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ckx-packs-test-'));
process.env.EXAMS_DIR = tempDir;

const packService = require('../src/services/packService');

function mcqBundle(overrides = {}) {
  return {
    packFormatVersion: 1,
    lab: {
      id: 'kcna-community-1',
      name: 'Community KCNA Pack',
      category: 'KCNA',
      description: 'Test pack',
      difficulty: 'Medium',
      examDurationInMinutes: 30,
      certificationCode: 'KCNA'
    },
    config: {
      examType: 'mcq',
      totalMarks: 100,
      lowScore: 50,
      mediumScore: 75,
      highScore: 90
    },
    assessment: {
      questions: [
        {
          id: '1',
          type: 'multiple-choice',
          domain: 'kcna-kubernetes-fundamentals',
          question: 'What is a Pod?',
          options: ['A node', 'The smallest deployable unit', 'A container image'],
          correctOptionIndexes: [1],
          weightage: 50,
          explanation: 'Pods wrap one or more containers.'
        },
        {
          id: '2',
          type: 'multiple-choice',
          domain: 'kcna-container-orchestration',
          question: 'Which component stores cluster state?',
          options: ['etcd', 'kube-proxy', 'CoreDNS'],
          correctOptionIndexes: [0],
          weightage: 50,
          explanation: 'etcd is the datastore.'
        }
      ]
    },
    answersMarkdown: '# Answers\n1. B\n2. A\n',
    scripts: { setup: {}, validation: {} },
    ...overrides
  };
}

function performanceBundle() {
  return {
    packFormatVersion: 1,
    lab: {
      id: 'cka-community-1',
      name: 'Community CKA Pack',
      category: 'CKA',
      difficulty: 'Hard',
      examDurationInMinutes: 60
    },
    config: { totalMarks: 100 },
    assessment: {
      questions: [
        {
          id: '1',
          namespace: 'ns-a',
          machineHostname: 'ckad9999',
          question: 'Fix the broken deployment',
          concepts: ['deployments'],
          verification: [
            { id: '1', description: 'deployment ready', verificationScriptFile: 'q1_s1_validate.sh', weightage: 60 },
            { id: '2', description: 'service routes', verificationScriptFile: 'q1_s2_validate.sh', weightage: 40 }
          ]
        }
      ]
    },
    answersMarkdown: '# Answers\n',
    scripts: {
      setup: { 'q1_setup.sh': '#!/bin/bash\nkubectl create ns ns-a\n' },
      validation: {
        'q1_s1_validate.sh': '#!/bin/bash\nexit 0\n',
        'q1_s2_validate.sh': '#!/bin/bash\nexit 0\n'
      }
    }
  };
}

describe('Pack Service', () => {
  beforeAll(() => {
    fs.writeFileSync(path.join(tempDir, 'labs.json'), JSON.stringify({ labs: [] }, null, 2));
  });

  afterAll(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  describe('validateBundle', () => {
    it('accepts a valid MCQ bundle', () => {
      const result = packService.validateBundle(mcqBundle());
      expect(result.valid).toBe(true);
      expect(result.examType).toBe('mcq');
    });

    it('accepts a valid performance bundle', () => {
      const result = packService.validateBundle(performanceBundle());
      expect(result.valid).toBe(true);
      expect(result.examType).toBe('performance');
    });

    it('rejects malformed bundles with clear errors', () => {
      expect(packService.validateBundle(null).valid).toBe(false);
      expect(packService.validateBundle({}).valid).toBe(false);

      const badVersion = packService.validateBundle(mcqBundle({ packFormatVersion: 99 }));
      expect(badVersion.errors.join(' ')).toContain('packFormatVersion');
    });

    it('rejects unsafe pack ids and script names (path traversal)', () => {
      const badId = mcqBundle();
      badId.lab.id = '../escape';
      expect(packService.validateBundle(badId).valid).toBe(false);

      const badScript = performanceBundle();
      badScript.scripts.validation['../../etc/passwd'] = 'evil';
      const result = packService.validateBundle(badScript);
      expect(result.valid).toBe(false);
      expect(result.errors.join(' ')).toContain('unsafe file name');
    });

    it('rejects MCQ bundles that smuggle scripts', () => {
      const bundle = mcqBundle();
      bundle.scripts.setup['sneaky.sh'] = '#!/bin/bash\necho hi\n';
      const result = packService.validateBundle(bundle);
      expect(result.valid).toBe(false);
      expect(result.errors.join(' ')).toContain('data-only');
    });

    it('rejects weight sums that do not match totalMarks', () => {
      const bundle = mcqBundle();
      bundle.assessment.questions[0].weightage = 10;
      const result = packService.validateBundle(bundle);
      expect(result.valid).toBe(false);
      expect(result.errors.join(' ')).toContain('sum');
    });

    it('rejects performance bundles with missing referenced scripts', () => {
      const bundle = performanceBundle();
      delete bundle.scripts.validation['q1_s2_validate.sh'];
      const result = packService.validateBundle(bundle);
      expect(result.valid).toBe(false);
      expect(result.errors.join(' ')).toContain('not included');
    });

    it('rejects oversized scripts', () => {
      const bundle = performanceBundle();
      bundle.scripts.setup['big.sh'] = '#'.repeat(200 * 1024);
      const result = packService.validateBundle(bundle);
      expect(result.valid).toBe(false);
      expect(result.errors.join(' ')).toContain('exceeds');
    });
  });

  describe('import / export round trip', () => {
    it('imports a valid MCQ bundle and registers it', async () => {
      const result = await packService.importPack(mcqBundle());
      expect(result.imported).toBe(true);

      const packs = await packService.listPacks();
      const imported = packs.find((pack) => pack.id === 'kcna-community-1');
      expect(imported).toBeDefined();
      expect(imported.imported).toBe(true);
      expect(imported.examType).toBe('mcq');
      expect(imported.questionCount).toBe(2);
    });

    it('re-importing the same pack id is rejected as duplicate (no uncontrolled copies)', async () => {
      const result = await packService.importPack(mcqBundle());
      expect(result.imported).toBe(false);
      expect(result.duplicate).toBe(true);

      const packs = await packService.listPacks();
      expect(packs.filter((pack) => pack.id === 'kcna-community-1')).toHaveLength(1);
    });

    it('validateOnly runs all checks without writing', async () => {
      const bundle = mcqBundle();
      bundle.lab.id = 'kcna-community-2';
      const result = await packService.importPack(bundle, { validateOnly: true });
      expect(result.valid).toBe(true);
      expect(result.imported).toBe(false);

      const packs = await packService.listPacks();
      expect(packs.find((pack) => pack.id === 'kcna-community-2')).toBeUndefined();
    });

    it('export of an imported pack round-trips to an importable bundle', async () => {
      const exported = await packService.exportPack('kcna-community-1');
      expect(exported.success).toBe(true);
      expect(exported.bundle.assessment.questions).toHaveLength(2);

      // Round trip: re-import under a new id
      exported.bundle.lab.id = 'kcna-community-roundtrip';
      const reimported = await packService.importPack(exported.bundle);
      expect(reimported.imported).toBe(true);
    });

    it('imports a performance bundle with executable scripts', async () => {
      const result = await packService.importPack(performanceBundle());
      expect(result.imported).toBe(true);

      const scriptPath = path.join(tempDir, 'imported', 'cka-community-1', 'scripts', 'validation', 'q1_s1_validate.sh');
      expect(fs.existsSync(scriptPath)).toBe(true);
      const mode = fs.statSync(scriptPath).mode & 0o777;
      expect(mode & 0o100).toBeTruthy(); // owner-executable
    });
  });

  describe('deleteImportedPack', () => {
    it('deletes imported packs but refuses unknown ids', async () => {
      const result = await packService.deleteImportedPack('kcna-community-roundtrip');
      expect(result.deleted).toBe(true);

      const missing = await packService.deleteImportedPack('does-not-exist');
      expect(missing.deleted).toBe(false);
    });
  });
});
