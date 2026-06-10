# CK-X Phase 0 Baseline Audit (CKS Migration)

Date: 2026-06-11
Branch: `feat/cks-phase0-baseline`
Scope: read-only verification + registry hygiene only. No features added.

## 1. Findings

### 1.1 Git baseline

- Working tree was clean at Phase 0 start (branch cut from `main` at `12e14c8`).
- `facilitator/assets/exams/cka/001/` was deleted in commit `12e14c8`
  ("after CKA exam pass") and is confirmed missing locally.

### 1.2 Registry vs. folders (`labs.json`)

- 9 labs were registered; 8 lab folders exist.
- Missing registered lab: `cka-001` → `assets/exams/cka/001` (folder absent).
  **Fixed in Phase 0**: entry removed from `labs.json` (backup kept).
- Orphan lab folders (exist but unregistered): **none**.
- All other 8 registered labs resolve to existing folders:
  `ckad-001`, `ckad-002`, `cks-001`, `docker-001`, `cka-004`, `cka-005`,
  `cka-007`, `helm-001`.

### 1.3 cks-001 structure verification

| Check | Result |
| --- | --- |
| `config.json` exists | PASS |
| `assessment.json` exists | PASS |
| `answers.md` exists | PASS |
| Setup scripts exist | PASS (21 files) |
| Validation scripts exist | PASS (87 files) |
| Every `verificationScriptFile` exists on disk | PASS (38/38 referenced) |
| 2–5 validations per question | PASS (all 12 questions) |
| `machineHostname` = `ckad9999` per question | PASS |
| `bash -n` on all 108 scripts | PASS |
| **Total validation weightage = 100** | **FAIL — total is 60** (12 questions × 5) |

Additional cks-001 integrity issues found (not fixed in Phase 0 — out of
allowed scope):

- **Weightage mismatch**: `config.json` declares `totalMarks: 100`, but
  `assessment.json` weightages sum to 60. Scoring partially self-corrects
  (the facilitator computes percentage against the actual sum), but this
  violates the repo rule that weightage must total exactly 100.
- **8 orphan setup scripts**: `q13_setup.sh` … `q20_setup.sh` exist but have
  no matching questions. `prepare-exam-env.sh` runs **all**
  `scripts/setup/q*_setup.sh`, so these will execute at exam start and create
  cluster resources for questions that don't exist (slower start, confusing
  cluster state).
- **49 orphan validation scripts**: on disk but unreferenced by
  `assessment.json` (harmless at runtime — only referenced scripts run —
  but they suggest the lab was cut from 20 questions to 12 without cleanup).
- The lab appears to be a stock/legacy lab predating this repo's quality
  rules. Recommendation: repair or regenerate it in Phase 1 before using it
  as the smoke-test lab.

### 1.4 Executable permissions (informational, not a blocker)

All scripts in `ckad/001`, `ckad/002`, `cks/001`, `other/001`, `other/002`
lack the executable bit in the repo (CKA labs 004/005/007 have it). This is
**not a runtime blocker**: `jumphost/scripts/prepare-exam-env.sh:56` runs
`find /tmp/exam-assets -type f -exec chmod +x {} \;` after extracting
`assets.tar.gz`. Repo rules still require exec bits on newly generated labs.

### 1.5 Docker Compose verification

- `docker compose config` **could not run**: the `docker` CLI is not
  available in this WSL distro right now (Docker Desktop not running or WSL
  integration disabled). Runtime validation deferred — see Blockers.
- Static verification performed instead: both `docker-compose.yaml` and
  `docker-compose.override.yaml` parse as valid YAML.

### 1.6 Port exposure

- `docker-compose.yaml`: only published port is
  `nginx → 127.0.0.1:${CKX_HTTP_PORT:-30081}:80` (localhost-only). PASS.
- `docker-compose.override.yaml`: publishes **no** ports. PASS.
- No new public ports introduced by Phase 0 (no compose changes at all).

## 2. Changed files (Phase 0)

| File | Change |
| --- | --- |
| `facilitator/assets/exams/labs.json` | Removed stale `cka-001` entry (folder verified missing) |
| `facilitator/assets/exams/labs.json.phase0.bak` | New — pre-change backup of the registry |
| `migration-plan.md` | Corrected CKS domain weights (Cluster Setup 15%, Cluster Hardening 15%, System Hardening 10%, Minimize Microservice Vulnerabilities 20%, Supply Chain Security 20%, Monitoring/Logging/Runtime Security 20%); clarified cka/001 is fixed only because it is verified missing locally |
| `migration-audit.md` | New — this report |

No labs deleted. No compose changes. No k3d changes. No new tooling.

## 3. Validation commands used

```bash
git status
ls facilitator/assets/exams/cka/001                      # confirms missing
python3 - <<'EOF'   # registry vs folders cross-check (labs.json assetPath → isdir)
python3 - <<'EOF'   # cks-001: weightage sum, script refs, 2–5 validations
bash -n scripts/setup/*.sh scripts/validation/*.sh        # in cks/001
find scripts -name '*.sh' ! -perm -u+x | wc -l            # exec-bit census
python3 -m json.tool facilitator/assets/exams/labs.json   # JSON validity
python3 -c "yaml.safe_load(...)"                          # both compose files
docker compose config                                     # FAILED: docker CLI unavailable
```

Post-change validation: `labs.json` is valid JSON, 8 labs registered,
`cka-001` absent, backup file present and identical to pre-change state.

## 4. Blockers

1. **Docker CLI unavailable in this WSL distro** — start Docker Desktop and
   enable WSL integration, then run `docker compose config` and an end-to-end
   `cks-001` smoke test before Phase 1 work begins.
2. **cks-001 quality debt** (weightage 60 ≠ 100; 8 orphan setup scripts that
   run at exam start; 49 orphan validation scripts). Must be repaired or the
   lab regenerated in Phase 1 before it is trusted as a smoke-test baseline.

No blockers for committing Phase 0 itself.

## 5. Next recommended branch

`feat/cks-phase1-pipeline` — CKS content pipeline on the current k3d backend:

1. Repair or regenerate `cks-001` (fix weightage to 100, remove orphan
   scripts) and run the end-to-end smoke test (requires Docker Desktop up).
2. Jumphost image v2: add trivy, kube-bench, kubesec, cosign, syft/bom,
   etcdctl, openssl, jq/yq as pinned static binaries.
3. Create `.claude/skills/cks-exam-generator-2026/`,
   `docs/cks-lab-generation-guide.md`, and the CLAUDE.md CKS rules
   (16 questions / 120 min default, corrected domain weights, backend
   capability matrix).
4. Generate `cks/002` (first hard k3d-safe practice lab) with full quality
   gates: weightage = 100, false-positive audit, `bash -n`, exec bits,
   validation-report.md.
