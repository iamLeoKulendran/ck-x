/**
 * Tests for the certification profile configuration
 *
 * Guards the invariants the UI and analytics rely on:
 * unique codes, complete profiles, and domain weights summing to 100.
 */

const fs = require('fs');
const path = require('path');

const configPath = path.join(__dirname, '..', 'assets', 'certifications.json');

describe('certifications.json', () => {
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

  it('has a version envelope and a certifications array', () => {
    expect(config.version).toBe(1);
    expect(Array.isArray(config.certifications)).toBe(true);
    expect(config.certifications.length).toBeGreaterThanOrEqual(5);
  });

  it('contains the five supported certifications with unique codes', () => {
    const codes = config.certifications.map((cert) => cert.code);
    expect(new Set(codes).size).toBe(codes.length);
    ['CKA', 'CKAD', 'CKS', 'KCNA', 'KCSA'].forEach((code) => {
      expect(codes).toContain(code);
    });
  });

  describe.each(JSON.parse(fs.readFileSync(configPath, 'utf8')).certifications.map((cert) => [cert.code, cert]))(
    '%s profile',
    (code, cert) => {
      it('has required fields', () => {
        expect(typeof cert.displayName).toBe('string');
        expect(cert.displayName.length).toBeGreaterThan(0);
        expect(['performance', 'multiple-choice']).toContain(cert.examFormat);
        expect(cert.defaultDurationMinutes).toBeGreaterThan(0);
        expect(cert.passThresholdPercent).toBeGreaterThan(0);
        expect(cert.passThresholdPercent).toBeLessThanOrEqual(100);
        expect(Array.isArray(cert.questionTypes)).toBe(true);
        expect(cert.questionTypes.length).toBeGreaterThan(0);
        expect(typeof cert.scoringPolicy).toBe('string');
      });

      it('has blueprint metadata with source and retrieval date', () => {
        expect(cert.blueprint).toBeDefined();
        expect(typeof cert.blueprint.version).toBe('string');
        expect(cert.blueprint.source).toMatch(/^https:\/\//);
        expect(cert.blueprint.retrievedAt).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      });

      it('domain weights sum to exactly 100', () => {
        const total = cert.blueprint.domains.reduce((sum, domain) => sum + domain.weightPercent, 0);
        expect(total).toBe(100);
      });

      it('domains have unique ids, names, and keyword lists', () => {
        const ids = cert.blueprint.domains.map((domain) => domain.id);
        expect(new Set(ids).size).toBe(ids.length);
        cert.blueprint.domains.forEach((domain) => {
          expect(domain.name.length).toBeGreaterThan(0);
          expect(Array.isArray(domain.keywords)).toBe(true);
          expect(domain.keywords.length).toBeGreaterThan(0);
        });
      });

      it('multiple-choice certifications never use validation-script scoring', () => {
        if (cert.examFormat === 'multiple-choice') {
          expect(cert.scoringPolicy).not.toBe('weighted-validation-scripts');
          expect(cert.questionTypes).not.toContain('performance');
        }
      });
    }
  );
});
