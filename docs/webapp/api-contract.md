# Webapp API Contract (Migration Baseline)

Frozen snapshot of every network call the current vanilla frontend makes.
The React migration must reproduce these calls byte-identically (same
paths, methods, params, bodies). Extracted from `app/public/js/**` on the
commit that introduced this file.

Base URL: same origin (`http://localhost:30081`), all facilitator calls
prefixed `/facilitator/api/v1` (nginx → `facilitator:3000/api/v1`).

## Shared / cross-page

| Endpoint | Method | Used by | Notes |
| --- | --- | --- | --- |
| `/facilitator/api/v1/exams/current` | GET | index, exam, results | Active exam session (id, status). 404/empty ⇒ no session |
| `/facilitator/api/v1/exams/{id}/status` | GET | index, exam, results | Polled during lab prep and evaluation |
| `/facilitator/api/v1/exams/{id}/terminate` | POST | index, exam, results | Ends session, tears down lab |
| `/facilitator/api/v1/certifications` | GET | index, results | Certification type list |

## index.html (`js/index.js`)

| Endpoint | Method | Notes |
| --- | --- | --- |
| `/facilitator/api/v1/assements/` | GET | Exam catalog for the selection modal. **Path typo is real** — keep as-is until facilitator changes |
| `/facilitator/api/v1/exams/` | POST | Create exam session (body: selected exam), then poll `{id}/status` until ready → redirect to `/exam.html` |
| `/facilitator/api/v1/exams` | POST | Second create-variant call site (line ~618) — verify body shape when porting |
| `/facilitator/api/v1/exams/attempts` | GET | Previous-attempts table + summary + filters |

## exam.html (`js/exam.js` + `js/components/*`)

| Endpoint | Method | Notes |
| --- | --- | --- |
| `/facilitator/api/v1/exams/{id}/questions` | GET | Question list + metadata |
| `/facilitator/api/v1/exams/{id}/evaluate` | POST | Submit performance exam for evaluation |
| `/facilitator/api/v1/exams/{id}/mcq-submit` | POST | Submit MCQ answers (MCQ mode) |
| `/facilitator/api/v1/exams/{id}/events` | POST | Event tracking `{ events: [...] }`; failures swallowed (must not disrupt exam) |
| `/facilitator/api/v1/exams/metrics/{id}` | POST | Feedback submission |
| `/api/vnc-info` | GET | **Webapp Express route** (not facilitator) — VNC connection params |

Non-HTTP channels (must keep working untouched):

- **socket.io namespace `/ssh`** (`terminal-service.js`: `io('/ssh', …)`) —
  xterm.js terminal, served by webapp Express + socket.io. CDN scripts
  today: xterm 5.3.0, xterm-addon-fit 0.8.0, socket.io-client 4.7.2 (pin
  same versions as npm deps when porting).
- **VNC iframe** `src="/vnc-proxy/?<params>"` (`remote-desktop-service.js`)
  → webapp Express proxy → remote-desktop; noVNC websocket goes direct via
  nginx `/websockify`.

## results.html (`js/results.js`)

| Endpoint | Method | Notes |
| --- | --- | --- |
| `/facilitator/api/v1/exams/{id}/result` | GET | 404 ⇒ fall back to `{id}/status` polling until evaluated |
| `/facilitator/api/v1/exams/{id}/evaluate` | POST | Re-evaluate button |
| `/facilitator/api/v1/exams/attempts` | GET | History context |
| `/facilitator/api/v1/mistakes` | POST | Log mistakes from failed steps (JSON payload) |

## answers.html (`js/answers.js`)

| Endpoint | Method | Notes |
| --- | --- | --- |
| `/facilitator/api/v1/exams/{id}/answers` | GET | Markdown answers; rendered with highlight.js |

## analytics.html (`js/analytics.js`)

| Endpoint | Method | Notes |
| --- | --- | --- |
| `/facilitator/api/v1/analytics` | GET | `{ data: { totalAttempts, uncategorizedAttempts, certifications: [{ code, displayName, attemptCount, latestPercentage, bestPercentage, passThresholdPercent, blueprintVersion, scoreTrend[], domainMastery{}, readiness{} }] } }` |

## mistakes.html (`js/mistakes.js`)

| Endpoint | Method | Notes |
| --- | --- | --- |
| `/facilitator/api/v1/mistakes?{category,status}` | GET | Filterable list |
| `/facilitator/api/v1/mistakes/{id}/correction` | POST | Record correction |
| `/facilitator/api/v1/mistakes/{id}/retests` | POST | Schedule retest |
| `/facilitator/api/v1/mistakes/{id}/retests/{retestId}` | POST/PATCH | Complete retest (verify method at port time) |
| `/facilitator/api/v1/mistakes/{id}` | DELETE | Remove mistake |

## packs.html (`js/packs.js`)

| Endpoint | Method | Notes |
| --- | --- | --- |
| `/facilitator/api/v1/packs` | GET | Installed pack list |
| `/facilitator/api/v1/packs/{id}` | DELETE | Remove pack |
| `/facilitator/api/v1/packs/{id}/export` | GET | Download bundle (anchor `download`) |
| `/facilitator/api/v1/packs/import` | POST | Import bundle |
| `/facilitator/api/v1/packs/import?validateOnly={bool}` | POST | Builder validate / save |

## settings.html (`js/settings.js`)

| Endpoint | Method | Notes |
| --- | --- | --- |
| `/facilitator/api/v1/data/info` | GET | History file path, schema version, attempt count, telemetry |
| `/facilitator/api/v1/data/export` | GET | Backup download (plain anchor) |
| `/facilitator/api/v1/data/restore` | POST | Upload bundle; server backs up current file first |
| `/facilitator/api/v1/data/reset` | POST | Delete history (server writes backup first) |

## Porting rules

1. Paths byte-identical — including the `assements/` typo.
2. Error-state UX preserved: every page shows its "Failed to load … Is the
   facilitator running?" style message on fetch failure; exam event
   tracking swallows errors silently.
3. Polling loops (lab prep, evaluation) keep their intervals and terminal
   states.
4. `/api/vnc-info`, `/vnc-proxy/`, socket.io `/ssh`, `/websockify` are
   webapp/nginx infrastructure — the React app consumes them, never
   reimplements them.
