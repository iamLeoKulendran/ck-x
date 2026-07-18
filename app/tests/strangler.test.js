// Strangler routing contract: migrated routes serve the React build, every
// legacy path stays on the old static files, and removing a route entry
// rolls a page back. Run with: node --test tests/
// Requires webapp-react/dist to exist (npm run build in webapp-react).
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const fs = require('fs');
const express = require('express');
const request = require('supertest');

const ReactAppService = require('../services/react-app-service');

const PUBLIC_DIR = path.join(__dirname, '..', 'public');
const DIST_DIR = path.join(__dirname, '..', 'webapp-react', 'dist');

function buildApp(migratedRoutes) {
    const app = express();
    const reactAppService = new ReactAppService(DIST_DIR, migratedRoutes);
    reactAppService.setup(app);
    app.use(express.static(PUBLIC_DIR));
    return app;
}

test('react build output exists (run vite build first)', () => {
    assert.ok(fs.existsSync(path.join(DIST_DIR, 'index.html')), 'webapp-react/dist/index.html missing');
});

test('migrated route serves the React index', async () => {
    const app = buildApp(['/react-preview.html']);
    const res = await request(app).get('/react-preview.html');
    assert.strictEqual(res.status, 200);
    assert.match(res.headers['content-type'], /text\/html/);
    assert.match(res.text, /id="root"/);
    assert.match(res.text, /\/react-app\//);
});

test('react assets are served under /react-app/', async () => {
    const app = buildApp(['/react-preview.html']);
    const indexHtml = fs.readFileSync(path.join(DIST_DIR, 'index.html'), 'utf8');
    const assetMatch = indexHtml.match(/\/react-app\/(assets\/[^"]+\.js)/);
    assert.ok(assetMatch, 'no /react-app/ asset reference found in built index.html');
    const res = await request(app).get(`/react-app/${assetMatch[1]}`);
    assert.strictEqual(res.status, 200);
    assert.match(res.headers['content-type'], /javascript/);
});

test('missing react assets return 404, never legacy HTML', async () => {
    const app = buildApp(['/react-preview.html']);
    const res = await request(app).get('/react-app/assets/does-not-exist.js');
    assert.strictEqual(res.status, 404);
});

test('legacy pages are untouched', async () => {
    const app = buildApp(['/react-preview.html']);
    for (const page of ['/index.html', '/exam.html', '/settings.html', '/50x.html']) {
        const res = await request(app).get(page);
        assert.strictEqual(res.status, 200, `${page} should come from legacy public/`);
        assert.doesNotMatch(res.text, /id="root"/, `${page} must not be the React shell`);
    }
});

test('rollback: removing the route entry restores legacy behavior', async () => {
    const app = buildApp([]);
    const res = await request(app).get('/react-preview.html');
    // No legacy file of that name exists, so with the entry removed the
    // request falls through the static middleware (404 here; catch-all in
    // the real server). It must NOT serve the React shell.
    assert.notStrictEqual(res.status, 200);
});

test('phase 2: the four tool pages are served from the React build', async () => {
    const app = buildApp(ReactAppService.MIGRATED_ROUTES);
    for (const page of ['/settings.html', '/packs.html', '/mistakes.html', '/analytics.html']) {
        const res = await request(app).get(page);
        assert.strictEqual(res.status, 200, `${page} should be migrated`);
        assert.match(res.text, /id="root"/, `${page} must serve the React shell`);
        assert.match(res.text, /\/react-app\//, `${page} must load React assets`);
    }
});

test('phase 2: non-migrated pages still come from legacy public/', async () => {
    const app = buildApp(ReactAppService.MIGRATED_ROUTES);
    for (const page of ['/index.html', '/exam.html', '/results.html', '/answers.html', '/50x.html']) {
        const res = await request(app).get(page);
        assert.strictEqual(res.status, 200, `${page} should come from legacy public/`);
        assert.doesNotMatch(res.text, /id="root"/, `${page} must not be the React shell`);
    }
});

test('phase 2: legacy tool-page files remain on disk for instant rollback', () => {
    for (const file of [
        'settings.html', 'packs.html', 'mistakes.html', 'analytics.html',
        'js/settings.js', 'js/packs.js', 'js/mistakes.js', 'js/analytics.js'
    ]) {
        assert.ok(fs.existsSync(path.join(PUBLIC_DIR, file)), `${file} must stay for rollback`);
    }
});

test('phase 2 rollback: removing a tool-page entry restores the legacy page', async () => {
    const withoutSettings = ReactAppService.MIGRATED_ROUTES.filter((r) => r !== '/settings.html');
    const app = buildApp(withoutSettings);
    const res = await request(app).get('/settings.html');
    assert.strictEqual(res.status, 200);
    assert.doesNotMatch(res.text, /id="root"/, 'rolled-back page must be the legacy file again');
    assert.match(res.text, /js\/settings\.js/, 'rolled-back page must load the legacy script');
});

test('missing dist is a graceful no-op', async () => {
    const app = express();
    const service = new ReactAppService(path.join(__dirname, 'does-not-exist'), ['/react-preview.html']);
    service.setup(app);
    app.use(express.static(PUBLIC_DIR));
    const res = await request(app).get('/index.html');
    assert.strictEqual(res.status, 200);
});
