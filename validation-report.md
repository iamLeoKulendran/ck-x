# Validation Report

## Git Setup

- Requested branch: `feature/persistent-attempt-history`
- Result: not created because this workspace does not contain a `.git` directory.
- `git status --short`: failed with `fatal: not a git repository (or any of the parent directories): .git`.

## Static Checks

- `node --check facilitator\src\services\attemptHistoryService.js`: passed
- `node --check facilitator\src\services\jumphostService.js`: passed
- `node --check facilitator\src\controllers\examController.js`: passed
- `node --check facilitator\src\routes\examRoutes.js`: passed
- `node --check app\public\js\index.js`: passed

## Functional Smoke Tests

- Attempt history JSON service was tested with a temporary `ATTEMPT_HISTORY_FILE`.
- The smoke test validated:
  - Missing history file is created automatically.
  - Two concurrent `appendAttempt` calls complete through the in-process write queue.
  - Failed validation steps are extracted.
  - Failed concepts are summarized.
  - Improvement trend is calculated for repeated attempts on the same lab.
- During smoke testing, the service was improved to use Node's built-in `crypto.randomUUID()` instead of the external `uuid` package.

## Frontend Wiring Checks

- Checked `app/public/js/index.js` `getElementById(...)` calls against IDs present in `index.html` or dynamic modal templates.
- Result: 30 IDs checked, 0 missing.
- Removed one old unused helper that referenced missing `#examDropdown`.

## UI/UX Review

- Previous Attempts is visible on the landing page before the feature cards, so users can review results without opening the exam selector.
- Empty, loading, and error states are present.
- Filters support category, lab, failed concept, and date range.
- Summary cards surface total attempts, top weak area, latest failed attempt, and improvement trend.
- The table shows lab/category/date, score, weak areas, and failed validation-step details.
- Responsive CSS collapses the summary, filters, and table layout to one column on smaller screens.

## UI/UX Follow-Up Recommendations

- Consider adding a small "Jump to Previous Attempts" link in the hero area if the section feels too far down after real browser testing.
- Consider a details drawer/modal for long failed-validation lists if many attempts make table rows too tall.
- Consider an export button later if you want easy manual backups from the UI.

## Docker Compose

- `docker compose config`: passed
- Confirmed facilitator environment includes `ATTEMPT_HISTORY_FILE=/usr/src/app/data/attempt-history.json`.
- Confirmed facilitator mounts named volume `attempt-history` at `/usr/src/app/data`.
- Docker emitted a warning reading `C:\Users\Leo\.docker\config.json` due to access denied, but the command completed successfully.

## Package Scripts

- `npm.cmd test` in `facilitator`: failed because the project script is a placeholder: `echo "Error: no test specified" && exit 1`.
- `npm.cmd run build` in `facilitator`: failed because no `build` script exists.
- `npm.cmd test` in `app`: failed because no `test` script exists.
- `npm.cmd run build` in `app`: failed because no `build` script exists.
- Direct `npm` commands were blocked by PowerShell execution policy for `npm.ps1`, so `npm.cmd` was used.

## Manual Review Notes

- Existing `/facilitator/api/v1/assements/` spelling is preserved.
- Existing Redis active exam/result flow is preserved.
- Attempt history is stored separately and is not deleted by exam termination.
- No new ports were added.

## Health Fix Validation - 2026-05-01

- Fixed facilitator asset packaging permissions by making `/usr/src/app/assets`, `/usr/src/app/logs`, and `/usr/src/app/data` writable by the non-root `nodeuser` during the facilitator image build.
- Updated `facilitator/entrypoint.sh` so startup creates `assets.tar.gz` without deleting source `scripts/` directories.
- Updated only CKA original lab scoring:
  - `facilitator/assets/exams/cka/001/assessment.json`: total weightage is now `100`.
  - `facilitator/assets/exams/cka/002/assessment.json`: total weightage is now `100`.
- `docker compose config`: passed. Docker still warns about `C:\Users\Leo\.docker\config.json` access denied, but config generation succeeds.
- JSON validation: `jq` was not available locally, so both changed JSON files were validated with PowerShell `ConvertFrom-Json`.
- Shell syntax validation: `bash -n` passed for `facilitator/entrypoint.sh` and all `115` shell scripts under CKA `001` and `002`.
- Rebuilt and restarted facilitator with `docker compose up -d --no-deps --build facilitator`.
- Fresh facilitator logs no longer show `Permission denied` or `tar: can't open 'assets.tar.gz'`.
- Verified `assets.tar.gz` exists for CKA `001` and `002` inside the rebuilt facilitator container.
- Verified source `scripts/` directories remain present for CKA `001` and `002`.
- Verified `/usr/src/app/data/attempt-history.json` still exists and was not deleted.
