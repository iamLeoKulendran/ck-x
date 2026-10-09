# Frontend Migration Plan — Vanilla HTML/Bootstrap → React

Status: in progress — Phase 4 implementation (`41bdd12`) and acceptance fixes
(`b89ffd9`) are committed behind `/exam-react.html`. The screenshot-driven Exam
workspace/theme correction is implemented and green but uncommitted; Leo must
restart the full timed performance + MCQ acceptance against that corrected
React route before the default-route cutover. See
`docs/handoffs/ck-x-react-migration-current.md` for the exact human checklist.
Scope: the browser UI and its static delivery path under `app/`. Facilitator API,
nginx, jumphost, cluster runtime, remote desktop, and the Express webapp
server's websocket/VNC duties stay untouched.

**Requirement (updated): dual theme.** The React app ships BOTH light and
dark themes with a navbar toggle, matching the reference site
(ui-ux-pro-max-skill.nextlevelbuilder.io) in both modes. See §3a.

---

## 1. Feasibility verdict

**Yes — a safe migration is possible without breaking anything and without a
performance regression, on two conditions:**

1. **Ship the React app as static files** (SPA build or Next.js static
   export). No SSR server. The current UI is static files behind nginx; a
   static React build is the same deployment class — same nginx, same
   Express server, same Docker layout, no new runtime.
2. **Migrate page-by-page behind nginx (strangler pattern), exam page
   last.** Old and new pages coexist during migration; every page keeps its
   URL; rollback is a one-line nginx/Express change.

Why this is low-risk here specifically:

- The frontend is a **thin client**. All state lives in the facilitator API
  (`/facilitator/api/v1/*`). No frontend rewrite touches data.
- The two realtime channels — socket.io `/ssh` (xterm terminal) and
  `/vnc-proxy` + `/websockify` (noVNC desktop) — are **served by the Express
  webapp server and nginx, not by page code**. The exam page consumes them
  via iframes/sockets; a React exam page consumes the exact same endpoints.
- Pages are already isolated (9 HTML files, one JS file each). Each maps
  cleanly to one route/component tree.

### Framework choice: Vite + React SPA (recommended) vs Next.js

| | Vite + React SPA | Next.js (static export) |
| --- | --- | --- |
| Fits a local Docker app | Best — one `dist/` of static files | Good — `output: 'export'` produces the same |
| SSR/ISR/image-optimization | Not needed | Unused (must stay disabled — enabling SSR adds a Node runtime for zero benefit) |
| Build speed / config surface | Smaller | Larger |
| Ecosystem (shadcn/ui, Tailwind, TanStack Query, Recharts) | Identical | Identical |
| Multi-page routing | React Router | App Router (file-based) |

**Recommendation: Vite + React + TypeScript + Tailwind + shadcn/ui.**
Next.js's differentiators (SSR, ISR, server actions, edge) are all useless
for a localhost Docker app — you'd carry the framework weight without the
payoff. If you still prefer Next.js for familiarity, use
`output: 'export'` and treat every "SSR/route handler" feature as
forbidden; the rest of this plan applies unchanged either way.

---

## 2. What could break, and the counter-measure

| Risk | Severity | Counter-measure |
| --- | --- | --- |
| Exam page realtime (socket.io terminal, VNC iframe, timers, pause, panel layout) | High | Migrate exam page **last**, in its own phase, behind a flag; keep vanilla `exam.html` until React version passes a full mock exam end-to-end |
| API contract drift (accidental changes to fetch paths/params) | Medium | Freeze the contract first: write `docs/webapp/api-contract.md` listing every endpoint each page calls (they exist in the current JS); new pages must call identical endpoints |
| URL changes breaking bookmarks / redirects (`exam.html?id=…`, `results.html?id=…`) | Medium | Keep every existing URL. SPA router aliases `*.html` paths; Express serves the SPA for those routes |
| Session flow (start exam → poll status → redirect → exam → results) | Medium | Playwright e2e for the whole flow, recorded against the current app **before** migration starts, replayed against each migrated page |
| Docker image bloat / build breakage | Low | Multi-stage build: node build stage → copy `dist/` into the same slim runtime image; CI check that image size stays within budget |
| Bootstrap removal changing look | Low | Port `ckx-theme.css` tokens into Tailwind config first; visual parity screenshots per page |
| Performance regression (bundle, hydration) | Low if static | Budgets: ≤ 200 KB gz JS per route, code-split per route, lazy-load charts, no CDN fonts (local-first rule), Lighthouse ≥ current scores as a gate |

Performance reality check: today's pages load Bootstrap 5 + Font Awesome
from CDNs (~90 KB gz CSS/JS + FA). A tree-shaken Tailwind + shadcn build is
typically smaller, loads from localhost, and removes the CDN dependency —
so done right this migration **improves** performance and offline behavior.

---

## 3a. Theming requirement (dual theme, reference-exact)

Both themes replicate the reference site's look. The toggle is an icon
button in the navbar, matching the reference: **moon icon while in light
mode, sun icon while in dark mode** (the icon shows the mode you switch to).

**Light theme (reference frame 1):**
- Canvas: soft off-white (`#f4f6fb`-family) with large pastel radial glows —
  light blue upper-left/center, soft peach/orange right — same composition
  as dark mode's glow, lighter opacity.
- Navbar: white glass pill (translucent white + blur, thin light border).
- Ink: near-black headings, slate secondary text.
- Cards/tiles: white surfaces, thin light borders, soft shadows; stat
  numbers/icons stay blue.
- Primary button: same blue; secondary: white with border.
- Hero gradient text: same blue→purple→orange blend (reads on light).
- **Terminal command chip stays dark in both themes** (reference does this).
- Exam terminal/VNC panels stay dark in both themes (terminals are dark).

**Dark theme:** current implemented design (near-black canvas, indigo/amber
glow, glass navbar) — unchanged.

**Mechanics:**
- Tokens: every color exposed as CSS custom properties under
  `:root[data-theme="light"]` / `:root[data-theme="dark"]`; Tailwind reads
  the variables (`darkMode: ['selector', '[data-theme="dark"]']`), so
  components are written once.
- Default: follows `prefers-color-scheme`; user choice persisted in
  `localStorage("ckx-theme")`; inline `<head>` script applies the stored
  theme before first paint (no flash of wrong theme).
- Bootstrap-era pages (during migration): not retrofitted — legacy pages
  stay dark-only; the toggle ships with the React pages. Cutover ends the
  split.
- Charts: series palette must be validated **per surface** (light and dark)
  with the dataviz palette validator; each theme may use different steps of
  the same hues.
- Gates gain a second axis: visual parity screenshots and contrast checks
  run in BOTH themes for every migrated page.

## 3. Phases

Each phase ends with: Playwright flows green, visual diff reviewed, Docker
compose build passing, rollback path intact. Do not start the next phase
with a red gate.

### Phase 0 — Baseline and contract freeze (no code changes)
- Write `docs/webapp/api-contract.md`: every endpoint, method, params,
  response shape used by each page (extracted from current `js/*.js`).
- Record Playwright e2e flows against the current app: start-exam happy
  path, results, answers, packs import/export, settings backup/restore/
  reset, analytics render, mistakes CRUD.
- Capture full-page screenshots of all 9 pages (both empty-state and
  with-data) as the visual baseline.

### Phase 1 — Scaffold and design system
- `app/webapp-react/`: Vite + React + TS + Tailwind + shadcn/ui +
  React Router + TanStack Query.
- Build the dual-theme token set (§3a): light + dark CSS variables, theme
  toggle + persistence + no-flash script; port `ckx-theme.css` dark values
  and derive the light set from the reference.
- Build Nav (with theme toggle), Card, StatTile, Tag, ScorePill, Table,
  Modal, Toast components — written once against tokens, rendered in both
  themes in a component gallery page for review.
- Multi-stage Dockerfile change: build stage produces `dist/`; Express
  gains one rule — serve migrated routes from `dist/`, everything else from
  `public/` (the strangler switch, one array of route names).

### Phase 2 — Low-risk tool pages
- Migrate **Settings → Packs → Mistakes → Analytics** (in that order —
  simplest first; analytics brings the chart component, port the SVG trend
  chart as a React component with the same validated palette).
- Each page: same URL, same API calls, same features. Gate: e2e + visual
  parity + empty-state/error-state parity ("Failed to load… facilitator
  running?" messages preserved).

### Phase 3 — Home, Results, Answers
- Home: hero, stat tiles, exam-selection modal, lab-prep progress overlay
  (polling logic ports as a TanStack Query poll), previous-attempts table.
- Results/Answers: read-only views; answers keeps highlight.js (lazy-loaded)
  and markdown rendering.
- Gate: full start-exam flow e2e against a real compose stack — modal →
  progress → redirect → (legacy) exam → results → answers.

### Phase 4 — Exam page (the hard one)
- Port piece-by-piece into React: header/timer/pause → question panel +
  navigation/flag/complete state machine → terminal panel (socket.io +
  xterm in a `useEffect`-managed component, same `/ssh` namespace) → VNC
  iframe panel (same `/vnc-proxy` URL) → MCQ mode → help drawer → paused
  overlay.
- Keep `exam.html` (vanilla) reachable at `/exam-legacy.html` until the
  React exam has passed: one full timed mock, pause/resume, reconnect after
  container restart, MCQ pack exam, evaluation handoff.
- Only then flip the default.

### Phase 5 — Cutover and cleanup
- All routes served from `dist/`; legacy `public/` HTML+JS deleted except
  assets; remove Bootstrap/FA CDN references; `50x.html` stays static
  (nginx serves it when webapp is down — it must not be part of the SPA).
- Update `docs/user-guide.md` and `docs/webapp/*` for the new structure.
- Final full-stack e2e + Lighthouse + image-size check.

### Phase 6 — The payoff (new features, post-migration)
Now the actual motivation: dashboard and features become cheap —
e.g. richer analytics dashboard (domain trends over time, per-question
heatmaps), exam-history compare view, in-app lab browser, keyboard-driven
question navigation, theme polish. Each is a normal React feature instead
of a hand-rolled DOM script.

---

## 4. Effort estimate (rough, sequential)

| Phase | Size |
| --- | --- |
| 0 Baseline + contract | done (`c85c104`) |
| 1 Scaffold + dual-theme design system | done (`c038cba`) |
| 2 Tool pages (×4, both themes) | done (`6b812bc`) |
| 3 Home/Results/Answers | done (`b281acd`) |
| 4 Exam page | implementation + fixes green (`41bdd12`, `b89ffd9`); human acceptance pending |
| 5 Cutover | blocked on human Phase 4 acceptance |
| **Total** | **~10–16 focused days** |

---

## 5. Hard rules for the migration

1. No SSR runtime. Static build output only.
2. No facilitator/nginx/compose service changes beyond the webapp
   Dockerfile build stage and the Express static-routing switch.
3. Every page keeps its URL and its API calls byte-identical.
4. Exam page migrates last and only replaces vanilla after a full passed
   mock exam on the React version.
5. Local-first stays: no CDN assets in the final build, no telemetry.
6. A red gate (e2e, visual parity, build) blocks the next phase.
