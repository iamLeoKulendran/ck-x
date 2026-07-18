# CK-X User Guide

How to run the app and use every page: exams, question packs, settings,
analytics, mistakes, and attempt history (backup, restore, reset).

Everything in CK-X is local. Attempt history, packs, and analytics live on
this machine only — nothing is uploaded anywhere.

---

## 1. Running the app

Requirements: Docker with Docker Compose (Docker Desktop + WSL2 on Windows).

```bash
git clone <your-fork-or-clone-url>
cd ck-x
docker compose up -d
```

Or use the helper script, which deploys and opens the browser for you:

```bash
./compose-deploy.sh
```

Then open:

```
http://localhost:30081
```

The port is controlled by the `CKX_HTTP_PORT` environment variable
(default `30081`, bound to `127.0.0.1` only). To change it:

```bash
CKX_HTTP_PORT=8080 docker compose up -d
```

Common operations:

| Action | Command |
| --- | --- |
| Start / redeploy after code changes | `docker compose up -d` |
| Stop the app (data kept) | `docker compose down` |
| Stop and delete volumes (data lost) | `docker compose down -v` |
| View logs | `docker compose logs -f` |

Lab environments take 3–5 minutes to prepare when you start an exam.

---

## 2. Pages at a glance

| Page | URL | Purpose |
| --- | --- | --- |
| Home | `/` | Start an exam, review previous attempts |
| Exam | `/exam.html` | Live exam: questions + terminal/desktop split view |
| Results | `/results.html` | Score, per-question outcomes after evaluation |
| Answers | `/answers.html` | Step-by-step solutions for a finished attempt |
| Analytics | `/analytics.html` | Trends computed from your stored attempts |
| Mistakes | `/mistakes.html` | Mistake log, corrections, delayed retests |
| Packs | `/packs.html` | Import/export/build question packs |
| Settings | `/settings.html` | Local data info, backup, restore, reset |

---

## 3. Starting an exam

1. On the Home page click **Start Exam**.
2. Pick a **Certification Type** (CKA, CKS, KCNA, KCSA, …) and an **Exam**.
3. Click **START EXAM** and wait while the lab environment is prepared
   (3–5 minutes). You are redirected to the exam interface automatically.
4. Work the questions in the left panel; the terminal/desktop is on the right.
   Use **Flag** to mark questions for review and **Mark Complete** to track
   progress. The timer and pause button are in the header.
5. Finish (or let the timer expire) and the attempt is evaluated. Results,
   answers, weak areas, and mistakes are stored in your local history.

Previous attempts appear on the Home page under **Previous Attempts**, with
score pills, weak areas, and failed questions. Filter by category, lab,
weak area, or date range.

---

## 4. Question Packs (`/packs.html`)

A pack is a shareable `ckx-pack-*.json` bundle containing an exam's
questions. Performance-lab authoring stays file-based (see
`docs/cka-lab-generation-guide.md` and `docs/cks-lab-generation-guide.md`);
the Packs page handles import/export and browser-built MCQ packs.

### Installed packs

The table lists every installed pack: id, name, category, type, question
count, and source. Per-pack actions:

- **Export** — downloads the pack as a `ckx-pack-<id>.json` bundle you can
  share or keep as a backup.
- **Delete** — removes the pack from this machine.

### Import a pack

1. Click **Choose File** and select a `ckx-pack-*.json` bundle.
2. Click **Validate & import**. The bundle is validated before anything is
   written: schema, marks sum (must equal 100), script references,
   file-name safety, size limits, and duplicate ids. Errors are listed on
   the page; nothing is imported until validation passes.

> **Security note:** performance packs contain shell scripts that run inside
> the CK-X exam sandbox (jumphost and practice cluster) when you start the
> lab — never on your host machine and never at import time. Only import
> packs from sources you trust.

### Build a multiple-choice pack

Author an original KCNA/KCSA-style MCQ pack in the browser:

1. Fill in **Pack id** (lowercase letters, digits, hyphens — e.g.
   `kcna-my-pack-1`), **Name**, **Category** (KCNA / KCSA / Other), and
   **Duration** in minutes.
2. Click **Add question** for each question; set options, the correct
   answer, and a weight. **Weights must sum to exactly 100.**
3. Click **Validate** to check the draft, then either:
   - **Save as pack** — installs it locally so it appears under Installed
     packs and in the Start Exam dialog, or
   - **Download bundle** — saves `ckx-pack-draft.json` to share or import
     later.

Never copy real exam questions — packs must be original content.

---

## 5. Settings & attempt history (`/settings.html`)

### Local data

Shows where your history lives and what is stored: history file path,
schema version, stored attempt count, and telemetry status (CK-X keeps all
data local).

### Save (back up) your history

Click **Download backup**. Every stored attempt is exported as one JSON
bundle (served from `/facilitator/api/v1/data/export`). Keep it anywhere —
another disk, cloud storage, a USB stick.

Back up before: resetting history, deleting volumes
(`docker compose down -v`), moving to another machine, or upgrading.

### Upload (restore) your history

1. Under **Restore**, choose a previously exported backup bundle (JSON).
2. Click **Restore from file**.

The restore **replaces** the current attempt history with the bundle's
contents. The current history file is backed up automatically next to the
history file before anything is written, so a bad restore is recoverable.

To move CK-X to a new machine: download a backup on the old machine, start
CK-X on the new one, and restore the bundle there.

### Remove (reset) your history

1. Under **Reset**, type `RESET` into the confirmation box — the button
   stays disabled until the text matches.
2. Click **Reset attempt history**.

All stored attempts are deleted and the UI shows an empty history. A backup
file is written next to the history file first, so the data can be
recovered manually if needed — but treat reset as destructive: download a
backup yourself before resetting.

---

## 6. Analytics (`/analytics.html`)

Charts and summaries computed from your stored attempts: score trends,
category breakdowns, and weak areas. Everything is derived from real
attempt data — when there is not enough evidence, CK-X says so instead of
inventing a score. Empty history means an empty Analytics page; complete an
exam first.

---

## 7. Mistakes & retests (`/mistakes.html`)

Failed steps from evaluated attempts are captured as mistakes. For each
mistake you can:

- record a **correction** (what you fixed and how),
- schedule and complete **delayed retests** to prove the fix stuck,
- **delete** entries that are no longer relevant.

A mistake counts as resolved only when a correction is logged **and** the
latest retest passed. Filter the list by category and status.

---

## 8. Troubleshooting

- **"Failed to load…" on Analytics/Mistakes/Packs/Home** — the facilitator
  backend is not reachable. Make sure the full stack is running
  (`docker compose up -d`) and you are on `http://localhost:30081`, not a
  static copy of the pages.
- **Exam page redirects to Home** — no active exam session. Start an exam
  from the Home page.
- **Lab preparation seems stuck** — initial setup takes 3–5 minutes;
  check `docker compose logs -f` if it takes much longer.
