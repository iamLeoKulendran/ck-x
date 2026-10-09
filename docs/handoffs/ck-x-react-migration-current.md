# CK-X React Migration — Current Handoff

Last independently verified: 2026-08-01 04:27 +05:30  
Project: `/home/leo/projects/ck-x`  
Branch: `feat/react-frontend-migration`  
Current committed HEAD: `b89ffd9` (`fix(exam): derive MCQ multiSelect and patch socket client`)  
Current uncommitted application batch: screenshot-driven React Exam workspace width + theme toggle correction

This is the durable cross-account continuation point. Read `CLAUDE.md`, `AGENTS.md`, `docs/frontend-react-migration-plan.md`, `docs/webapp/api-contract.md`, and this file before editing. Do not reconstruct state from an account-local chat.

## Current decision gate

Phases 0–3 are complete. Phase 4 implementation and its acceptance-fix batch are committed. A screenshot-driven React Exam layout/theme correction is now implemented and green but remains uncommitted. The React Exam stays behind `/exam-react.html` until Leo reruns the human acceptance matrix against this corrected build.

| Work | Commit | State |
| --- | --- | --- |
| Phase 0 — contract/browser baseline | `c85c104` | Complete |
| Dual-theme requirement | `3d8df6f` | Complete |
| Phase 1 — React foundation/strangler | `c038cba` | Complete |
| Phase 2 — Settings, Packs, Mistakes, Analytics | `6b812bc` | Complete |
| Phase 3 — Home, Results, Answers | `b281acd` | Complete |
| Phase 4 — React Exam preview | `41bdd12` | Implementation complete |
| Phase 4 acceptance fixes | `b89ffd9` | Complete and independently revalidated |
| Phase 4 layout/theme acceptance correction | uncommitted | Implemented, rebuilt, independently validated |
| Human Exam acceptance | — | **Restart against corrected `/exam-react.html` build** |
| Default Exam route flip / Phase 5 | — | Blocked until human acceptance passes |

The implementation commits intentionally exclude the current documentation edits. `AGENTS.md`, `CLAUDE.md`, the migration plan, and this handoff are expected uncommitted documentation changes; preserve them. The two current application edits are `app/webapp-react/src/exam/ExamPage.tsx` and `app/webapp-react/src/exam/exam-page.test.tsx`; do not lose or mix them with unrelated work.

## Current routing

React:

- `/exam-react.html?id=<exam-session-id>` — React Exam acceptance route
- all previously migrated Home, Results, Answers, Settings, Packs, Mistakes, and Analytics routes

Legacy/default:

- `/exam.html?id=<exam-session-id>` — current vanilla Exam default
- `/exam` — current extensionless vanilla alias
- `/exam-legacy.html?id=<exam-session-id>` — permanent vanilla escape hatch for cutover
- `/50x.html` — permanently standalone static page

Routing is controlled by `MIGRATED_ROUTES` and `LEGACY_ALIASES` in `app/services/react-app-service.js`. Do not flip the default Exam routes until Leo explicitly reports the acceptance result.

## Screenshot finding and current UI correction

Leo's 1920px screenshots showed an MCQ workspace only about 440px wide and a performance question pane only about 420px wide. Those dimensions match the still-default vanilla `/exam.html`, not the current React implementation. Live DOM proof on `/exam-react.html` showed the React MCQ panel occupied the full route before this correction. Any acceptance evidence must include the URL/path because the legacy and React shells intentionally look similar.

The current uncommitted React-only correction:

- adds the shared accessible `ThemeToggle` to the Exam header; it persists through the existing `ckx-theme` preference and changes its accessible label between “Switch to light theme” and “Switch to dark theme”;
- increases the performance question-pane default from 40% to 45%; at 1920px it is 864px while the desktop remains 1050px;
- protects useful drag proportions with 520px question/desktop targets where the viewport permits them;
- changes reset and divider double-click to restore the new 45% default;
- centers MCQ content in a responsive workspace capped at 1100px instead of allowing either a cramped legacy column or an uncontrolled full-width reading measure;
- leaves VNC and terminal surfaces unchanged and dark while application chrome/question content follows light or dark theme tokens.

Measured browser geometry after rebuilding the live webapp:

| Mode / viewport | Question | Desktop | Themes | Horizontal overflow |
| --- | ---: | ---: | --- | --- |
| Performance 1920×1080 | 864px | 1050px | dark + light | none |
| Performance 1024×768 | 512px | 506px | dark + light | none |
| Performance 390×844 | 195px | 189px | dark + light | none; split workspace is desktop-oriented and not suitable for doing a real performance lab |
| MCQ 1920×1080 | 1100px centered | hidden | dark + light | none |

Do not modify the vanilla Exam for this migration correction; verify the corrected UI at `/exam-react.html?id=...`.

## Acceptance-fix batch at `b89ffd9`

- Facilitator question sanitization derives `multiSelect` from `correctOptionIndexes.length > 1` before stripping the key.
- `correctOptionIndexes` and `explanation` are removed from every question type.
- Tests cover real KCNA question 4 plus non-MCQ leakage, missing key, empty key, and misleading author-set values.
- `socket.io-client` is 4.8.3; the server remains 4.7.2.
- Production dependency audit was clean when `b89ffd9` landed; see the current verification table for the later React Router advisory.
- Real `/ssh` proof passed polling connect, initial shell data, command round-trip, and reconnect after a forced engine close.
- The Phase 4 trailing-whitespace finding is fixed; `git show --check b89ffd9` passes.

## Independent verification of the current UI batch

| Gate | Result |
| --- | --- |
| React strict typecheck | Pass |
| React ESLint | Pass |
| React Vitest | 11 files, 96/96 passed |
| React production build | Pass |
| Production dependency audit | 2 high from newly published React Router RSC-only advisory `GHSA-qwww-vcr4-c8h2`; CK-X is a static BrowserRouter SPA and does not use RSC/actions. Latest published 7.x is still in the advisory range; `npm audit fix --dry-run` offered no dependency security change. Track separately; not introduced by this UI diff. |
| Express strangler tests | 17/17 passed |
| Facilitator Jest | 8 suites, 91/91 passed |
| Live Playwright baseline | 8/8 passed |
| Browser visual/geometry smoke | Performance mock at 1920/1024/390 and live evaluated MCQ at 1920, both themes; no horizontal overflow, toggle present/persistent |
| Compose stack | All 9 containers healthy |
| Commit check | `git show --check b89ffd9` passed |

Current production bundle:

- shared JavaScript: 97.04 KB gzip
- Exam: 95.97 KB gzip
- Exam CSS: 1.68 KB gzip

Known non-blocking test noise: timer-driven Home tests still emit React `act(...)` warnings while passing. This predates the Exam acceptance batch and does not block the manual Exam run.

## How to enter the React Exam

Home intentionally still redirects a newly prepared session to `/exam.html` while the migration is gated.

1. Start the selected exam normally from Home and wait for preparation to finish.
2. When the browser reaches `/exam.html?id=<id>`, do **not** start the legacy countdown.
3. Keep the complete query string and change only the path to `/exam-react.html?id=<same-id>`.
4. Start the React Exam there.

Opening `/exam-react.html` without `?id=` correctly redirects Home.

## Human acceptance run A — full timed performance mock

Use a real full performance mock such as `cka-004` or `cka-005`. A full 120-minute run is required for the timer gate; do not shorten the server duration or manipulate timestamps.

### Start and workspace

- [ ] React start modal and three-click countdown behave correctly.
- [ ] Timer begins once and never jumps backward or creates duplicate intervals.
- [ ] Questions, navigation dropdown, progress, Done, and Flag states render correctly.
- [ ] `[`, `]`, `F`, `D`, and `?` shortcuts work when the Exam workspace has focus.
- [ ] Shortcuts do not fire while typing in the terminal, while a modal is open, or while paused.
- [ ] Light/dark application theme works; terminal and VNC surfaces remain dark.
- [ ] No horizontal overflow or blocked controls at the viewport used for the mock.

### Terminal and VNC

- [ ] Terminal connects and displays the first shell prompt/data.
- [ ] Run a harmless command such as `pwd`; input and output work normally.
- [ ] Switch Terminal → VNC → Terminal; the shell session remains usable.
- [ ] Resize the browser/panel; xterm fits without clipping or duplicate terminals.
- [ ] VNC connects through `/vnc-proxy` and remains interactive.
- [ ] During this isolated run, restart `remote-terminal` and verify Terminal reconnects.
- [ ] Restart `remote-desktop` and verify VNC reconnects.

Use from a separate terminal only while no other user depends on the local stack:

```bash
cd /home/leo/projects/ck-x
docker compose restart remote-terminal
docker compose restart remote-desktop
```

### Persistence and pause

- [ ] Answer/Done/Flag several questions, navigate away, and return; state persists.
- [ ] Reload while active; current question, progress, flags, answers, and timer restore.
- [ ] Pause; the overlay blocks interaction and the timer stops.
- [ ] Reload while paused; the paused overlay/state restores.
- [ ] Resume; timer and workspace continue once, without duplicated sockets/listeners.

### Timed completion

Let the full performance mock run to zero so this one run proves the complete timer path:

- [ ] 30-minute warning appears once.
- [ ] 10-minute warning appears once.
- [ ] Under five minutes, the timer receives the red/urgent treatment.
- [ ] At zero, auto-submit/evaluation triggers once.
- [ ] React Results loads and eventually resolves the evaluation state.
- [ ] Completed/review mode does not allow shortcuts to mutate saved progress.
- [ ] Browser console has no uncaught errors and Network has no unexpected failed requests.

## Human acceptance run B — MCQ

Use `kcna-001` or `kcsa-001`.

- [ ] Start from Home, then change `/exam.html?id=...` to `/exam-react.html?id=...` as described above.
- [ ] KCNA question 4 or KCSA question 3 shows checkboxes and “Select all that apply,” not radios.
- [ ] Select multiple answers, navigate away/back, and reload; all selections persist.
- [ ] Single-answer questions still use radios and keep one selected answer.
- [ ] Manually submit before timeout; confirmation works and only one request is sent.
- [ ] Results score the multi-answer question correctly when the exact set is selected.
- [ ] Review mode renders the completed answers without mutating progress.

## Legacy escape-hatch check

After either completed session, open `/exam-legacy.html?id=<same-id>` in a separate tab:

- [ ] Vanilla Exam loads instead of the React shell.
- [ ] Completed/review behavior is reachable.
- [ ] `/exam.html` still serves vanilla until the explicit flip.

## Record the result

Report either:

```text
ACCEPTANCE PASS
Performance exam: <lab/id>
MCQ exam: <lab/id>
Timer warnings + timeout: pass
Pause/reload/state: pass
Terminal/VNC reconnect: pass
Results handoff: pass
Multi-select/scoring: pass
Legacy alias: pass
Console/network: clean
```

or, for each failure:

```text
ACCEPTANCE FAIL
Exam/session:
URL:
Step:
Expected:
Actual:
Console error:
Failed network request:
Does legacy behave correctly for the same step?:
```

Do not flip routes after a failure. Preserve the failed session and evidence for diagnosis.

## After an acceptance PASS

The next agent performs a small cutover-only batch:

1. Replace `/exam-react.html` in `MIGRATED_ROUTES` with both `/exam.html` and `/exam`.
2. Keep `/exam-legacy.html` serving the untouched vanilla page.
3. Add/adjust strangler tests for default React Exam, extensionless alias, legacy escape hatch, and one-line rollback.
4. Rebuild and rerun all gates plus route/browser smoke.
5. Commit the cutover separately.
6. Do not delete legacy Exam assets or begin broad cleanup in the cutover commit.

Compact post-pass prompt:

```text
Read the current CK-X handoff. Leo reports the complete React Exam acceptance matrix PASS. Perform only the default-route cutover: migrate `/exam.html` and `/exam`, retire `/exam-react.html` from `MIGRATED_ROUTES`, preserve `/exam-legacy.html`, add rollback/alias tests, rebuild, rerun all gates and browser route smoke, update the handoff, and commit separately. Do not delete legacy assets, change APIs/realtime infrastructure, push, deploy, or start broad Phase 5 cleanup.
```

## Safety

- One active editor per worktree.
- Preserve the uncommitted documentation changes.
- Do not reset, clean, stash, rebase, amend prior phase commits, force-push, deploy, or delete legacy files.
- Do not terminate an unrelated active exam to start acceptance.
- Do not expose answer keys through the question API.
- Do not proceed to cutover from automated tests alone; Leo’s human acceptance result is the gate.
