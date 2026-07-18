// Baseline e2e config. Requires the compose stack running:
//   docker compose up -d   →  http://127.0.0.1:30081  (CKX_HTTP_PORT)
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
    testDir: './specs',
    timeout: 30000,
    retries: 0,
    reporter: [['list']],
    use: {
        baseURL: process.env.CKX_BASE_URL || 'http://127.0.0.1:30081',
        viewport: { width: 1440, height: 900 },
        screenshot: 'only-on-failure'
    }
});
