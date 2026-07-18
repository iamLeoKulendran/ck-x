# CK-X e2e baseline (migration Phase 0)

Playwright tests that pin the current vanilla frontend's behavior before
the React migration. Every migrated page must keep these green.

## Run

```bash
docker compose up -d           # stack must be live on :30081
cd tests/e2e
npm install
npx playwright install chromium   # first time only
npm test
```

`CKX_BASE_URL` overrides the target (default `http://127.0.0.1:30081`).

Screenshots land in `tests/e2e/screenshots/` (gitignored) — the visual
baseline for parity comparison during migration.

## Not covered automatically

The full timed-exam flow (lab prep takes 3–5 minutes, spins up a cluster)
stays a **manual gate**: start a mock, answer one question in the terminal,
pause/resume, end exam, check results/answers/mistakes. Required before
the React exam page (migration Phase 4) replaces the vanilla one.
