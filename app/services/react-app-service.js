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
    '/analytics.html'
];

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

        console.log(`React strangler active for: ${this.migratedRoutes.join(', ') || '(none)'}`);
    }
}

module.exports = ReactAppService;
module.exports.MIGRATED_ROUTES = MIGRATED_ROUTES;
