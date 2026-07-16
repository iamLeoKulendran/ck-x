/**
 * Certification Catalog
 *
 * Loads certification profiles from assets/certifications.json and provides
 * helpers to map free-form question concepts onto blueprint domains.
 * The mapping is keyword-based and best-effort: concepts that match no
 * domain keywords are reported under the reserved "unmapped" bucket rather
 * than being silently assigned.
 */

const fs = require('fs');
const path = require('path');
const logger = require('./logger');

const CATALOG_PATH = path.join(process.cwd(), 'assets', 'certifications.json');
const UNMAPPED_DOMAIN_ID = 'unmapped';

let cachedCatalog = null;

function loadCatalog() {
  if (cachedCatalog) {
    return cachedCatalog;
  }

  try {
    const raw = fs.readFileSync(CATALOG_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.certifications)) {
      throw new Error('certifications.json has an invalid format');
    }
    cachedCatalog = parsed;
  } catch (error) {
    logger.error('Failed to load certification catalog', { error: error.message });
    cachedCatalog = { version: 0, certifications: [] };
  }

  return cachedCatalog;
}

function getCertification(code) {
  if (!code) {
    return null;
  }
  return loadCatalog().certifications.find((cert) => cert.code === code) || null;
}

/**
 * Map a question's concept strings to a blueprint domain id.
 * Returns the domain id with the most keyword hits, or "unmapped".
 */
function mapConceptsToDomain(certificationCode, concepts) {
  const certification = getCertification(certificationCode);
  if (!certification || !certification.blueprint || !Array.isArray(concepts) || concepts.length === 0) {
    return UNMAPPED_DOMAIN_ID;
  }

  const normalizedConcepts = concepts
    .filter((concept) => typeof concept === 'string')
    .map((concept) => concept.toLowerCase());

  let bestDomainId = UNMAPPED_DOMAIN_ID;
  let bestScore = 0;

  certification.blueprint.domains.forEach((domain) => {
    let score = 0;
    (domain.keywords || []).forEach((keyword) => {
      const normalizedKeyword = keyword.toLowerCase();
      normalizedConcepts.forEach((concept) => {
        if (concept === normalizedKeyword) {
          score += 2; // exact concept match outweighs substring hits
        } else if (concept.includes(normalizedKeyword) || normalizedKeyword.includes(concept)) {
          score += 1;
        }
      });
    });

    if (score > bestScore) {
      bestScore = score;
      bestDomainId = domain.id;
    }
  });

  return bestDomainId;
}

function getDomainName(certificationCode, domainId) {
  if (domainId === UNMAPPED_DOMAIN_ID) {
    return 'Unmapped';
  }
  const certification = getCertification(certificationCode);
  const domain = certification && certification.blueprint
    ? certification.blueprint.domains.find((entry) => entry.id === domainId)
    : null;
  return domain ? domain.name : domainId;
}

// Test hook: drop the cache so a fresh file read happens on next access
function resetCache() {
  cachedCatalog = null;
}

module.exports = {
  loadCatalog,
  getCertification,
  mapConceptsToDomain,
  getDomainName,
  resetCache,
  UNMAPPED_DOMAIN_ID
};
