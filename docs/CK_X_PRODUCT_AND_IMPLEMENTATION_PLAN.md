# CK-X Product and Implementation Plan

Status: living document. Created 2026-07-16 from an evidence-based audit of this
repository. Update the phase checklist as phases land.

---

## 1. Current-State Audit (2026-07-16)

Evidence labels used below:

- **runtime verified** — observed against the running Compose stack today.
- **source verified** — confirmed by reading code/config in this repository, or
  (for blueprints) first-party CNCF/Linux Foundation pages fetched today.
- **visible only** — seen in UI/docs but not exercised end to end.
- **not observed** — expected but not found.
- **blocked** — could not be verified with available tooling.
- **recommended** — proposed change, not a defect.

### 1.1 Stack and topology

- Docker Compose stack of 9 services: nginx (only published port,
  `127.0.0.1:30081`), webapp (static UI + Express), facilitator (Express API),
  redis (active exam state), jumphost (`ckad9999` SSH host), k8s-api-server
  (Docker-in-Docker k3d/K3s host), remote-desktop (noVNC), remote-terminal,
  registry (internal OCI registry for CKS supply-chain labs). **runtime
  verified** — all 9 report healthy; UI returns HTTP 200; labs and attempts
  APIs return real data.
- Frontend: vanilla JS + static HTML (`app/public`): `index.html` (landing,
  lab selector, previous attempts), `exam.html` (simulator), `results.html`,
  `answers.html`, `50x.html`. No framework, no bundler, no TypeScript.
  **source verified**
- Backend: `facilitator/src` Express app — controllers (exam, assessment,
  remoteDesktop, ssh), services (examService, jumphostService,
  attemptHistoryService, sshService, metricService, remoteDesktopService),
  Redis client util. **source verified**
- Lab content: `facilitator/assets/exams/<category>/<NNN>/` with `config.json`,
  `assessment.json`, `answers.md`, `scripts/setup/*.sh`,
  `scripts/validation/*.sh`; registry `facilitator/assets/exams/labs.json`.
  Existing labs: cka 004/005/007, ckad 001/002, cks 001–004, other 001/002.
  **source verified**

### 1.2 What already works

- Real cluster-backed lab runtime (k3d/K3s via DinD) with SSH candidate
  workspace, per-exam setup scripts, validation-script scoring, and weighted
  marks. **runtime verified** (stack healthy; scoring model source verified;
  real attempt records exist from June 2026 use)
- One-active-exam session lifecycle in Redis:
  CREATED → PREPARING → READY → EVALUATING → EVALUATED (+
  PREPARATION_FAILED / EVALUATION_FAILED). **source verified**
  (`examService.js`, `jumphostService.js`)
- Persistent attempt history: append-only JSON file
  (`/usr/src/app/data/attempt-history.json`, Docker volume
  `attempt-history`), atomic temp-file+rename writes, serialized write queue,
  `version: 1` envelope. Derived summary: weak concepts, most-failed
  questions, improvement trend, filters. **runtime verified** (API returns
  real attempts including failed-concept breakdowns)
- Solutions gating: `GET /exams/:id/answers` returns 403 until status is
  EVALUATED. **source verified** (`examController.js:211-219`)
- Timer with pause/resume persisted to localStorage
  (`ckx-exam-paused:{examId}`), restored on reload; threshold notifications at
  30/10/0 minutes; timeout auto-submits via `handleExamEnd`. **source
  verified** (`exam.js`, `timer-service.js`)
- Question navigator with flag and mark-as-done states, progress counts.
  **source verified** (`question-service.js`, `exam.js`)
- Local-only posture: nginx binds loopback; internal ports unpublished; Redis
  internal; telemetry disabled by compose default
  (`TRACK_METRICS=${TRACK_METRICS:-false}`). **source verified**

### 1.3 Defects and gaps

| # | Finding | Label |
|---|---------|-------|
| G1 | Flags, mark-as-done, and current-question position are in-memory only; a mid-exam reload loses them (timer is restored, marks are not). | source verified (`exam.js:56-57`, `question-service.js:169-182`) |
| G2 | No keyboard shortcuts; prev/next click-only; minimal ARIA (modals + toasts only). | source verified |
| G3 | Test infrastructure broken: `facilitator/tests/jumphostService.test.js` is Jest-style, but Jest is not a dependency and `npm test` exits with error. No configured lint/type/format gates; only `node --check` is documented. | runtime verified (`npm test` script is `exit 1`) |
| G4 | Redis TTL parameters pass `3600000` to `setEx` (seconds), i.e. ~41 days, while JSDoc says "1 hour". Works by accident; semantics wrong. | source verified (`redisClient.js:79,99,120`) |
| G5 | `metricService.js` defaults `TRACK_METRICS` to `true` in code and posts exam metadata to an external server; only the compose env default keeps it off. A code-level default of `false` is safer for a local-first product. | source verified |
| G6 | No certification/blueprint model. Categories are free strings in `labs.json`; landing-page filter labels hardcoded (CKAD/CKA/CKS/KCNA/KCSA/Other in `index.js:322-332`); domain weights live only in generator docs, not app data. | source verified |
| G7 | Attempt records lack: exam mode, duration-used seconds, per-question domain mapping, blueprint version. Domain-level analytics rely on free-form per-question `concepts` strings. | source verified |
| G8 | No question-pack import/export UI or API; adding labs means editing files in the repo. No validation pipeline in the app itself. | not observed |
| G9 | No MCQ engine; KCNA/KCSA (multiple-choice exams) cannot be represented; all scoring assumes cluster validation scripts. | not observed |
| G10 | No mistake-correction/retest model anywhere. | not observed |
| G11 | No backup/restore or history-export UI; backup documented only as `docker compose cp`. | source verified (README) |
| G12 | Browser-based route/viewport testing not possible in this environment (no local browser automation tooling). | blocked |
| G13 | Untimed/practice mode absent: every exam is timed with auto-submit. | source verified |
| G14 | `getExamAssets` is a placeholder returning `[]`. | source verified (`examService.js:178-208`) |
| G15 | Answers page pre-evaluation lock depends on backend 403 (good), but results page offers re-evaluate loops without guard against concurrent evaluation. | visible only |

### 1.4 Security posture (current)

- Only exposed port: `127.0.0.1:30081` (nginx). **source verified**
- Lab setup/validation scripts execute on the jumphost/k3d containers — never
  on the host — but they are arbitrary bash inside the lab environment. Adding
  a lab is equivalent to granting code execution in the sandbox. This is by
  design for a lab simulator; it must be documented as the trust boundary for
  any future pack-import feature. **source verified**
- Privileged containers required for DinD/k3d and desktop. Local-use only;
  README warns against public exposure. **source verified**

### 1.5 Certification blueprints (first-party, retrieved 2026-07-16)

| Cert | Blueprint | Format | Duration | Pass | Domains (weight %) |
|------|-----------|--------|----------|------|--------------------|
| CKA | v1.35 (cncf/curriculum) | performance | 120 min | 66% | Cluster Architecture, Installation & Configuration 25; Troubleshooting 30; Services & Networking 20; Workloads & Scheduling 15; Storage 10 |
| CKAD | v1.35 | performance | 120 min | 66% | Application Design and Build 20; Application Deployment 20; Application Observability and Maintenance 15; Application Environment, Configuration and Security 25; Services and Networking 20 |
| CKS | v1.34 | performance | 120 min | 67% | Cluster Setup 15; Cluster Hardening 15; System Hardening 10; Minimize Microservice Vulnerabilities 20; Supply Chain Security 20; Monitoring, Logging and Runtime Security 20 |
| KCNA | 2026 revision (unversioned file) | multiple-choice | 90 min | 75% | Kubernetes Fundamentals 44; Container Orchestration 28; Cloud Native Application Delivery 16; Cloud Native Architecture 12 |
| KCSA | unversioned | multiple-choice | 90 min | 75% | Overview of Cloud Native Security 14; Kubernetes Cluster Component Security 22; Kubernetes Security Fundamentals 22; Kubernetes Threat Model 16; Platform Security 16; Compliance and Security Frameworks 10 |

Sources: github.com/cncf/curriculum; training.linuxfoundation.org
certification pages; docs.linuxfoundation.org tc-docs FAQ (CKA/CKAD/CKS
passing scores) and multiple-choice FAQ (75%). These live in
`facilitator/assets/certifications.json` as configuration — never hardcoded
in components.

---

## 2. Product Goals and Non-Goals

### Goals

1. Local-first, credible exam-workstation simulator for CKA, CKAD, CKS
   (performance) and KCNA, KCSA (multiple-choice).
2. Community-authored, portable question content with safe import/export.
3. Trustworthy attempt history, transparent analytics, and a
   mistake-correction/retest loop that distinguishes captured → corrected →
   retested → passed.
4. Resume-safe attempts; no silent data loss on reload or crash.
5. All data local; documented backup/restore/reset.

### Non-Goals

- Cloud accounts, multi-tenancy, payments, social features.
- Visual cloning of Killer.sh or CNCF proprietary UI; copying real exam
  content.
- Replacing the k3d runtime with kubeadm in this plan (separately tracked in
  `docs/kubeadm-backend-upgrade-plan.md`; gated infrastructure phase).
- Rewriting the vanilla-JS/Express stack into a framework. The existing stack
  is small (~6.3k LOC), working, and stays.

## 3. User Journeys

1. **Take a mock exam**: pick certification → pick lab/pack → start → cluster
   provisions → solve tasks in desktop/terminal → flag/mark questions → submit
   or time out → evaluation → results → review answers → weak areas recorded.
2. **Resume after crash**: reopen UI mid-attempt → active session detected →
   timer, flags, done-marks, current question restored → continue.
3. **Review history**: browse attempts → filter by cert/lab/date/concept →
   inspect one attempt's failed questions and validation steps → queue
   failures for retest.
4. **Correct mistakes**: open mistake log → record root cause + corrective
   action → schedule delayed retest → later, retake the affected questions →
   pass/fail recorded against the original mistake.
5. **Author content**: create pack draft → add questions mapped to
   cert/domain → validate → preview in simulator → publish → export JSON →
   share; another user imports it with validation and duplicate detection.
6. **Study MCQ certs (KCNA/KCSA)**: start multiple-choice exam (no cluster) →
   answer/flag → submit → deterministic scoring → domain breakdown.

## 4. Information Architecture / Route Map

Current pages remain; new capability arrives as pages under the existing
static-HTML pattern:

| Route | Purpose | Status |
|-------|---------|--------|
| `/` (index.html) | Dashboard: quick start, cert filter, previous attempts, weak areas | exists; extend |
| `/exam.html?examId=` | Simulator workspace (labs: VNC+terminal; MCQ: question-only) | exists; extend |
| `/results.html?id=` | Results and review | exists; extend |
| `/answers.html?id=` | Post-evaluation solutions | exists |
| `/history.html` | Full attempt history + filters + export | new (Phase H) |
| `/mistakes.html` | Mistakes, corrections, retest queue | new (Phase M) |
| `/packs.html` | Question packs: list, import/export, builder | new (Phase Q) |
| `/settings.html` | Local data: backup, restore, reset, telemetry switch | new (Phase H/Q) |

Simulator stays a distraction-free mode; dashboard/analytics live outside it.

## 5. Certification / Profile Configuration

`facilitator/assets/certifications.json` (new, Phase C):

```json
{
  "version": 1,
  "certifications": [
    {
      "code": "CKA",
      "displayName": "Certified Kubernetes Administrator",
      "examFormat": "performance",
      "defaultDurationMinutes": 120,
      "passThresholdPercent": 66,
      "questionTypes": ["performance"],
      "scoringPolicy": "weighted-validation-scripts",
      "blueprint": {
        "version": "v1.35",
        "source": "https://github.com/cncf/curriculum",
        "retrievedAt": "2026-07-16",
        "domains": [
          { "id": "cka-troubleshooting", "name": "Troubleshooting", "weightPercent": 30, "keywords": ["troubleshooting", "logs", "monitoring"] }
        ]
      }
    }
  ]
}
```

- Served by `GET /facilitator/api/v1/certifications`.
- Domain entries carry `keywords` used to map per-question `concepts` to
  domains for analytics (best-effort mapping, clearly labeled).
- KCNA/KCSA profiles declare `"questionTypes": ["multiple-choice"]` and
  `"scoringPolicy": "mcq-equal-weight"`; the simulator must not assume
  cluster provisioning for them.
- `labs.json` entries gain optional `certificationCode` +
  `blueprintVersion`; `category` remains for backward compatibility.

## 6. Question-Pack Format and Versioning

A pack is the existing lab folder shape plus a manifest:

```json
{
  "packFormatVersion": 1,
  "packId": "uuid-or-reverse-dns",
  "name": "…", "author": "…", "license": "…",
  "certificationCode": "CKS", "blueprintVersion": "v1.34",
  "state": "draft|published",
  "contentVersion": 3,
  "questionsFile": "assessment.json",
  "checksum": { "algorithm": "sha256", "value": "…" }
}
```

- Export: zip (or single JSON for MCQ packs) of the lab folder + manifest.
- Import validation: JSON schema check, weightage sum = 100, script-file
  references exist, no path traversal (`..`, absolute paths) in any referenced
  file, size limits, duplicate detection by `packId` + `contentVersion`
  (re-import of same version is a no-op; newer version prompts upgrade;
  same-id-different-content flags conflict).
- **Threat model**: performance packs contain bash executed inside the
  jumphost/k3d sandbox — import UI must state this explicitly and require
  confirmation; scripts are never executed on the host or at import time; MCQ
  packs are data-only (no scripts allowed by schema). Imported markdown is
  rendered sanitized (no raw HTML).
- Published versions are immutable: editing a published pack creates
  `contentVersion + 1`; attempts snapshot the version they ran against.

## 7. Exam and Attempt Lifecycle

Backend session states (existing, kept):
`CREATED → PREPARING → READY → EVALUATING → EVALUATED`, failures
`PREPARATION_FAILED`, `EVALUATION_FAILED`, plus terminate at any point.

Attempt lifecycle (persistent record perspective):

```
started (snapshot: labId, contentVersion, blueprint, mode, durationPlanned)
  → in-progress (client autosave: flags, done-marks, currentQuestion, timer)
  → submitted (manual | timeout)          — atomic status transition
  → evaluated (scores appended, append-only)
  → reviewed (user opened results/answers)   [UI-level, optional]
abandoned/terminated attempts recorded with status, not silently dropped (Phase H)
```

Invariants:

- One active session at a time (existing constraint, kept).
- Autosave idempotent: same payload re-applied yields same state; keyed by
  `examId`.
- Timeout and manual submit funnel through the same `handleExamEnd` path.
- Attempt records are append-only; analytics derive from them and are
  reproducible.
- Exam definition data (questions, weights) is read from the lab assets at
  evaluation time today; packs phase adds content-version snapshotting.

## 8. Data Model

Existing durable store: `attempt-history.json` (version 1). New durable
stores follow the same pattern (JSON file + version envelope + atomic write +
write queue) in the `attempt-history` volume directory:

| Entity | Store | Phase |
|--------|-------|-------|
| Certification/BlueprintVersion/CurriculumDomain | `certifications.json` (read-only config) | C |
| ExamAttempt (+AttemptQuestion, ScoringEvent as embedded records) | `attempt-history.json` v2 (adds mode, durationUsedSeconds, certificationCode, blueprintVersion, domainBreakdown; v1 records upgraded read-side, never rewritten on disk without backup) | H |
| Mistake / Correction / RetestAttempt | `mistakes.json` v1 | M |
| QuestionPack / QuestionVersion | pack folders + `packs-index.json` | Q |
| UserPreference | `preferences.json` (browser localStorage for UI-only prefs) | H |
| DataExport | on-demand zip/JSON download, no PII beyond local history | H |

Migration policy: any schema bump writes `<file>.v<N>.bak` first;
reader accepts N and N-1; writer emits N; migrations tested with fixture
files.

## 9. Scoring and Analytics Definitions

- **Question score** = Σ weightage of passed validations (existing).
- **Attempt percentage** = totalScore / totalPossibleScore × 100 (existing).
- **Pass indicator** = percentage ≥ profile `passThresholdPercent`, shown with
  the threshold and blueprint source; absent when profile unknown.
- **Domain mastery** = per domain: earned/possible across attempts of that
  certification, using question→domain mapping (explicit `domain` field when
  present; keyword mapping fallback; unmapped shown as "Unmapped", never
  guessed silently).
- **Score trend** = attempt percentages over time per certification/lab.
- **Time-per-question**: requires per-question timing capture (Phase A2);
  until then, not shown (no fabricated values).
- **Readiness evidence** = rule-based, transparent: N attempts in window,
  latest ≥ threshold, no domain < 50%, retest backlog empty. Displayed as the
  list of satisfied/violated rules — never a synthetic single percentage when
  evidence is insufficient (<2 completed attempts ⇒ "insufficient evidence").
- All analytics computed from stored attempts on request; no demo data. Empty
  states must say "no attempts yet".

## 10. Mistakes, Corrections, Retests

Distinct facts stored per mistake (in `mistakes.json`):

```json
{
  "mistakeId": "…", "createdAt": "…",
  "source": { "attemptId": "…", "questionId": "…", "validationStepIds": ["…"] },
  "category": "concept-gap|syntax|misread|time-pressure|environment|other",
  "rootCauseNote": "…",
  "correction": { "status": "none|planned|done", "completedAt": null, "note": "" },
  "retests": [ { "retestAttemptId": "…", "scheduledFor": "date", "result": "pending|passed|failed", "attemptRef": "…" } ]
}
```

Rules:

- Capturing a mistake never marks it corrected.
- A passed retest sets retest result only; correction status stays whatever
  the user recorded.
- "Resolved" badge requires correction.status=done AND latest retest passed.
- Repeated failures (same question/domain failing across ≥2 attempts) are
  surfaced automatically from attempt history.

## 11. Persistence, Backup, Restore

- All durable data in the `attempt-history` Docker volume (single backup
  target) + lab/pack assets.
- `GET /facilitator/api/v1/data/export` → JSON bundle download (history,
  mistakes, preferences opt-in). Restore via upload with validation +
  pre-restore automatic backup file.
- Reset procedure documented in README (replace file with empty envelope);
  never `down -v` as the documented path.

## 12. Terminal / Lab Sandbox Boundary

- Real runtime exists (k3d in DinD) — preserved untouched by this plan.
- Trust boundary: pack scripts run only inside jumphost/k3d containers on the
  Docker network; the facilitator/webapp never execute pack content; the host
  filesystem, Docker socket, and user kubeconfigs are never exposed to pack
  content. Import UI must display a code-execution warning for performance
  packs.
- MCQ packs: pure data; schema forbids script references.

## 13. Accessibility and Responsive Requirements

- Keyboard: prev/next (←/→ or [ / ]), flag (F), mark done (D), navigator
  (G then number or dropdown focus), submit dialog focus-trapped, ESC closes
  modals. Shortcuts documented in an in-simulator help panel and disabled
  while typing in terminal/inputs.
- ARIA: navigator states (answered/flagged/current) conveyed via text/labels,
  not color alone; toasts already `aria-live`.
- `prefers-reduced-motion` respected for transitions.
- Responsive targets: 390 / 768 / 1024 / 1440 px. Simulator is
  desktop-first (VNC needs width) — at <768px show explicit "best on desktop"
  banner rather than broken layout; dashboard/history/analytics fully
  responsive.
- Verification: manual + scripted checks; browser automation currently
  unavailable in the dev environment (**blocked** — revisit with Playwright
  container).

## 14. Implementation Phases and Checklist

Phase 0/1 are this document. Implementation phases are ordered, each ends at
a clean, validated boundary:

- [x] **P0 — Audit** (2026-07-16)
- [x] **P1 — This plan**
- [x] **PC — Certification profiles** (2026-07-16): `certifications.json` +
      `GET /api/v1/certifications` + landing-page labels driven by config +
      pass-threshold indicator on results page + telemetry code default off +
      Jest test infra restored (39 tests).
- [x] **PA — Attempt resilience (autosave)** (2026-07-16): flags, done-marks,
      and current question persisted per `examId` in
      `ckx-exam-progress:{examId}`; restored in `initExamUI`; cleared on
      submit/timeout/terminate; stale keys swept on the landing page.
- [x] **PH — History & data safety** (2026-07-16): attempt record v2 (mode,
      durationUsedSeconds, certificationCode, blueprintVersion,
      domainBreakdown), read-side v1 support with one-time `.v1.bak` backup,
      `GET/POST /api/v1/data/{info,export,restore,reset}`, settings page,
      `DELETE /api/v1/exams/attempts/:id` with backup, Redis TTL semantics
      fixed (named 7-day constant).
- [x] **PAn — Analytics** (2026-07-16): `GET /api/v1/analytics` + analytics
      page; score trend (threshold line), domain mastery incl. unpracticed
      domains, rule-based readiness evidence, insufficient-evidence states.
- [x] **PM — Mistakes & retests** (2026-07-16): `mistakes.json` store + API,
      capture button on failed results questions, correction workflow, retest
      queue with due dates, resolved = correction done AND latest retest
      passed (unit-tested), mistakes page, included in data export/restore.
- [x] **PMCQ — Multiple-choice engine** (2026-07-16): MCQ schema, no-cluster
      READY flow, server-side deterministic scoring (`mcq-submit`), answer
      key stripped pre-evaluation, MCQ exam UI (options, autosave, hidden VNC
      panel), original `kcna-001`/`kcsa-001` sample packs.
- [x] **PQ — Question packs** (2026-07-16): JSON bundle export/import with
      validation (schema, weights, script refs, traversal, size), duplicate
      409, sandbox code-execution warning, packs page, browser MCQ builder
      with validate-only pre-flight, imported packs persisted via bind mount.
      Simulator preview of drafts deferred (import-then-run covers it).
- [x] **PAx — Accessibility & responsive pass** (2026-07-16): exam shortcuts
      ([ ] F D ?) with typing/terminal/modal guards, aria-live progress,
      focus-visible styles, prefers-reduced-motion on all pages. Full
      browser-automation viewport audit still blocked (no tooling).
- [x] **PD — Distribution polish** (2026-07-16): README sections for packs,
      data safety, testing, MCQ; plan checklist maintained.
- [ ] **PK — kubeadm backend** (separately gated; existing plan doc).

Fix-alongside items: G4 (TTL semantics) in PH; G5 (telemetry code default) in
PC or PD; G3 (test runner) starts in PC (add Jest, make existing test pass).

## 15. Test Strategy

- Add Jest to facilitator (`npm test` must pass); unit tests for
  attemptHistoryService (record build, filters, summary), certifications
  loader, migration v1→v2, mistakes rules (§10), pack import validation
  (malformed, traversal, duplicate, oversize), MCQ scoring.
- `node --check` across all JS (existing gate, keep).
- API smoke script against the running stack (curl-based) for
  certifications/attempts/export endpoints.
- E2E lab flow remains manual/scripted via existing stack (documented
  checklist); browser automation adopted when tooling available.
- Every phase: run full gate set before declaring the phase done.

## 16. Acceptance Criteria (measurable)

1. `GET /facilitator/api/v1/certifications` serves all 5 profiles; landing
   filter renders from it (no hardcoded label list remains in `index.js`).
2. Mid-exam reload preserves timer AND flags/done-marks/current question
   (manual test scripted in docs).
3. Attempt records include mode/duration/cert fields; old records still load
   (fixture test).
4. Export endpoint returns a valid JSON bundle; restore of that bundle on a
   clean volume reproduces history (round-trip test).
5. Analytics show "insufficient evidence" with <2 attempts and never render
   fabricated values.
6. Mistake resolved-badge requires correction done + retest passed (unit
   tests).
7. Pack import rejects: bad JSON, weight sum ≠ 100, missing script refs, path
   traversal, duplicate same-version re-import (unit tests + manual).
8. MCQ exam completes with no cluster provisioned; scoring deterministic.
9. `npm test` passes; `node --check` clean; `docker compose config -q` clean.
10. No new published ports; telemetry default off at code level.

## 17. Risks and Trade-offs

- **Vanilla-JS growth**: more pages without a framework risks duplication.
  Mitigation: shared `components/` modules, keep pages thin. Rewrite is
  explicitly out of scope.
- **Concept→domain keyword mapping is heuristic**: label mapped analytics as
  best-effort; encourage explicit `domain` on new content.
- **Pack scripts are code execution in the sandbox**: mitigated by explicit
  trust boundary, warning UI, no host execution; residual risk accepted for a
  local lab tool.
- **Browser automation unavailable**: responsive/a11y evidence partially
  manual until tooling added.
- **Single-active-exam model**: simplifies runtime; multi-attempt concurrency
  is a non-goal.
- **Deferred**: kubeadm backend, cloud anything, AI features, per-question
  timing capture (PA2 candidate), attempt comparison UI (post-PAn).
