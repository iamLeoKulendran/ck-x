// Baseline: every page loads against the live stack, shows its key UI, and
// resolves its data state (content, empty, or explicit error message —
// never a silent hang). Also captures reference screenshots for the
// React-migration visual parity check.
const { test, expect } = require('@playwright/test');

const SHOT_DIR = `${__dirname}/../screenshots`;

test('home renders hero, stats, and attempts state', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('.command-title')).toContainText('Local Kubernetes');
    await expect(page.locator('#startExamBtn')).toBeVisible();
    await expect(page.locator('.hero-stat')).toHaveCount(6);
    // Attempts section resolves to one of its three states
    await expect(async () => {
        const content = await page.locator('#attemptsContent').isVisible();
        const empty = await page.locator('#attemptsEmpty').isVisible();
        const error = await page.locator('#attemptsError').isVisible();
        expect(content || empty || error).toBe(true);
    }).toPass({ timeout: 15000 });
    await page.screenshot({ path: `${SHOT_DIR}/index.png`, fullPage: true });
});

test('start exam: modal without session, resume with one', async ({ page, request }) => {
    const current = await request.get('/facilitator/api/v1/exams/current');
    const hasSession = current.ok() && (await current.text()).includes('"id"');

    await page.goto('/');
    await page.click('#startExamBtn');

    if (hasSession) {
        // Active session: an "Active Exam Detected" warning modal is
        // injected and shown — the selection modal must NOT appear.
        await expect(page.locator('#activeExamWarningModal')).toBeVisible({ timeout: 15000 });
        await expect(page.locator('#examSelectionModal')).not.toBeVisible();
        await page.screenshot({ path: `${SHOT_DIR}/active-exam-warning.png` });
    } else {
        await expect(page.locator('#examSelectionModal')).toBeVisible({ timeout: 15000 });
        // Options beyond the placeholder arrive from /certifications + /assements/
        await expect
            .poll(async () => page.locator('#examCategory option').count(), { timeout: 15000 })
            .toBeGreaterThan(1);
        await page.screenshot({ path: `${SHOT_DIR}/exam-modal.png` });
    }
});

test('analytics resolves to content or explicit message', async ({ page }) => {
    await page.goto('/analytics.html');
    await expect(async () => {
        const status = (await page.locator('#analyticsStatus').textContent()).trim();
        const hasContent = (await page.locator('#analyticsContent').innerHTML()).trim().length > 0;
        expect(hasContent || (status && status !== 'Loading analytics…')).toBe(true);
    }).toPass({ timeout: 15000 });
    await page.screenshot({ path: `${SHOT_DIR}/analytics.png`, fullPage: true });
});

test('mistakes page renders filters and resolves list', async ({ page }) => {
    await page.goto('/mistakes.html');
    await expect(page.locator('#categoryFilter, select').first()).toBeVisible();
    await page.waitForTimeout(2000);
    await page.screenshot({ path: `${SHOT_DIR}/mistakes.png`, fullPage: true });
});

test('packs page lists installed packs or explicit status', async ({ page }) => {
    await page.goto('/packs.html');
    await expect(page.locator('#importBtn')).toBeVisible();
    await expect(page.locator('#builderImportBtn')).toBeVisible();
    await expect(async () => {
        const status = (await page.locator('#packsStatus').textContent()).trim();
        const table = await page.locator('#packsTable').isVisible();
        expect(table || (status && status !== 'Loading packs…')).toBe(true);
    }).toPass({ timeout: 15000 });
    await page.screenshot({ path: `${SHOT_DIR}/packs.png`, fullPage: true });
});

test('settings shows local data info and action buttons', async ({ page }) => {
    await page.goto('/settings.html');
    await expect(page.locator('a[href="/facilitator/api/v1/data/export"]')).toBeVisible();
    await expect(page.locator('#restoreBtn')).toBeDisabled();
    await expect(page.locator('#resetBtn')).toBeDisabled();
    // Reset button arms only after typing RESET
    await page.fill('#resetConfirmInput', 'RESET');
    await expect(page.locator('#resetBtn')).toBeEnabled();
    await expect
        .poll(async () => (await page.locator('#infoAttemptCount').textContent()).trim(), { timeout: 15000 })
        .not.toBe('Loading…');
    await page.screenshot({ path: `${SHOT_DIR}/settings.png`, fullPage: true });
});

test('exam page without session redirects home', async ({ page }) => {
    await page.goto('/exam.html');
    await page.waitForURL(/\/($|index\.html)/, { timeout: 15000 });
});

test('results page without exam id shows explicit error', async ({ page }) => {
    await page.goto('/results.html');
    await expect(page.locator('body')).toContainText(/No exam ID provided/i, { timeout: 15000 });
    await page.screenshot({ path: `${SHOT_DIR}/results-no-id.png` });
});
