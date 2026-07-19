const fs = require('fs');
const path = require('path');
const express = require('express');

// Strangler switch for the React migration. Routes listed in
// MIGRATED_ROUTES are served from the React build; everything else falls
// through to the legacy static middleware. Rolling a page back is deleting
// its entry here — nothing else changes.
const MIGRATED_ROUTES = [
    '/react-preview.html',
    // Phase 2 — tool pages (each entry added only after its focused tests
    // passed; delete a line to roll that page back to legacy public/)
    '/settings.html',
    '/packs.html',
    '/mistakes.html',
    '/analytics.html',
    // Phase 3 — home, results, answers (extensionless /results matches the
    // legacy catch-all alias used by index.js redirects)
    '/',
    '/index.html',
    '/results.html',
    '/results',
    '/answers.html',
    // Phase 4 — React exam preview. /exam.html stays legacy until the React
    // exam passes a full timed mock (see the migration plan); the flip is
    // swapping '/exam-react.html' for '/exam.html' here.
    '/exam-react.html'
];

// Legacy pages that must stay reachable at an alias while (or after) their
// primary URL is migrated. Served straight from public/.
const LEGACY_ALIASES = {
    '/exam-legacy.html': 'exam.html'
};

// Vite builds with base '/react-app/', so assets never collide with
// legacy public/ paths.
const ASSET_PREFIX = '/react-app';

class ReactAppService {
    constructor(distDir, migratedRoutes) {
        this.distDir = distDir || path.join(__dirname, '..', 'webapp-react', 'dist');
        this.migratedRoutes = migratedRoutes || MIGRATED_ROUTES;
    }

    isAvailable() {
        return fs.existsSync(path.join(this.distDir, 'index.html'));
    }

    // Must be mounted BEFORE the legacy express.static middleware.
    setup(app) {
        if (!this.isAvailable()) {
            console.warn(`React build not found at ${this.distDir} — serving legacy pages only`);
            return;
        }

        app.use(ASSET_PREFIX, express.static(this.distDir, { index: false }));
        // Asset misses must 404, not fall through to the legacy HTML catch-all
        app.use(ASSET_PREFIX, (req, res) => {
            res.status(404).end();
        });

        const indexHtml = path.join(this.distDir, 'index.html');
        for (const route of this.migratedRoutes) {
            app.get(route, (req, res) => {
                res.sendFile(indexHtml);
            });
        }

        const publicDir = path.join(__dirname, '..', 'public');
        for (const [route, file] of Object.entries(LEGACY_ALIASES)) {
            app.get(route, (req, res) => {
                res.sendFile(path.join(publicDir, file));
            });
        }

        console.log(`React strangler active for: ${this.migratedRoutes.join(', ') || '(none)'}`);
    }
}

module.exports = ReactAppService;
module.exports.MIGRATED_ROUTES = MIGRATED_ROUTES;
module.exports.LEGACY_ALIASES = LEGACY_ALIASES;
