---
name: cks-exam-generator-2026
version: 1.0.0
license: MIT
description: Repository-native CK-X Simulator lab generator for original, high-quality CKS 2026 mock exams, topic practice sets, single practice questions, and clearly-labeled bridge labs for topics the current k3d backend cannot run for real. Use when the user asks to create or review CKS mock exams, security labs, NetworkPolicy labs, RBAC hardening labs, Pod Security Admission labs, supply chain security labs, trivy/kubesec/cosign/syft labs, runtime security labs, or audit-log analysis labs.
metadata:
  author: Leo
  target: Claude Code
  project: CK-X-Exam-Simulator
  category: Kubernetes CKS exam generation
---

# CKS Exam Generator 2026 for CK-X

## Mission

Generate and maintain high-quality CK-X Simulator CKS lab packages inside the user's repository. The goal is original CKS/Killer.sh-grade security practice quality: serious Kubernetes security scenarios first, then practical adaptation so the tasks are runnable and gradable inside CK-X on the current k3d/K3s backend.

"Killer.sh-style" means format, rigor, timing, scoring, and review workflow only. It never means copying content.

Questions should feel like serious CKS security scenarios: harden-this-broken-thing, find-the-violation, lock-down-this-workload, analyze-this-artifact. Validated by real end state wherever the current backend supports it. Avoid toy create-only tasks.

This skill is repository-native for Claude Code. When the user asks to generate a lab, create or update files directly in the repository after inspecting the current CK-X structure, and confirm only when an overwrite or risky decision is involved.

## Legal, Originality, and Safety Boundary

All generated content must be original.

Hard boundaries:

- Do not copy, scrape, leak, or reproduce real CKS exam tasks.
- Do not copy, scrape, leak, or reproduce Killer.sh, PSI, CNCF, or Linux Foundation content.
- Do not reproduce paid training, private exam, NDA-protected, or leaked content.
- Do not claim generated content is official CNCF, Linux Foundation, PSI, Kubernetes, Killer.sh, or real exam content.
- If the user provides legally usable notes, PDFs, or custom material, transform the concepts into original CK-X scenarios for private practice.
- Do not copy source material word-for-word unless the user explicitly owns it and asks for exact preservation.
- Do not claim official exam equivalence.

Safe rewrite example:

- Unsafe request: "Copy Killer.sh CKS questions into CK-X."
- Safe response: "Create original Killer.sh-grade CKS security scenarios with similar difficulty and topic coverage, without copying wording, structure, object names, or paid/private content."

## Official-Style CKS Alignment

Use the public CKS domain model and performance-based command-line style.

Default exam shape:

- Full CKS mock duration: 120 minutes.
- Full mock default question count: 16.
- Allowed range: 15 to 18 questions, only when explicitly requested.
- Difficulty default: Hard.
- Generate Medium or Easy only when explicitly requested.
- Questions must be performance-based command-line Kubernetes security tasks.

Use these domain weights:

| Domain | Weight |
| --- | ---: |
| Cluster Setup | 15% |
| Cluster Hardening | 15% |
| System Hardening | 10% |
| Minimize Microservice Vulnerabilities | 20% |
| Supply Chain Security | 20% |
| Monitoring, Logging and Runtime Security | 20% |

For a 16-question full mock, a practical domain split is:

- Cluster Setup: 2-3 questions
- Cluster Hardening: 2-3 questions
- System Hardening: 1-2 questions
- Minimize Microservice Vulnerabilities: 3 questions
- Supply Chain Security: 3 questions
- Monitoring, Logging and Runtime Security: 3 questions

If the user asks for latest official syllabus confirmation and internet access is available, verify against official CNCF/Linux Foundation sources before generation. If internet is unavailable, use the domain model above and report that official-source verification was not performed.

## Backend Capability Matrix

The current CK-X backend is k3d/K3s (single cluster, no kubeadm, no host AppArmor/eBPF control). Every generated task must be classified against this matrix before generation. See `references/ckx-cks-backend-capability-matrix.md` for the full version.

### Tier 1 — k3d-safe now (generate as real runnable tasks)

- NetworkPolicy (k3s enforces natively)
- RBAC (Roles, ClusterRoles, bindings, `kubectl auth can-i`)
- ServiceAccount hardening (automount, least privilege, token projection)
- Pod Security Admission namespace labels (enforced natively in k3s)
- SecurityContext (runAsNonRoot, capabilities, readOnlyRootFilesystem, seccomp)
- seccomp `RuntimeDefault` profile
- ValidatingAdmissionPolicy (CEL-based, built into current k8s)
- Gatekeeper or Kyverno, if the setup script installs them
- Ingress TLS, if the setup script installs an ingress controller or uses the bundled Traefik
- trivy / kubesec / cosign / syft static analysis tasks (tools are installed on the jumphost)
- Secrets management, encryption-at-rest concepts via static analysis
- Audit-log analysis from planted log files
- Dockerfile and manifest security review from planted files
- yq/jq-driven manifest hardening tasks

### Tier 2 — requires host capability later (do NOT generate as real tasks)

- AppArmor profiles
- Falco / eBPF runtime detection
- gVisor RuntimeClass

### Tier 3 — requires kubeadm backend later (do NOT generate as real tasks)

- real API server flag hardening
- real audit logging configuration (`--audit-policy-file`, `--audit-log-path`)
- real EncryptionConfiguration plus etcdctl verification of encrypted data
- real kubelet config hardening
- kube-bench remediation against real control-plane files
- static pod manifest troubleshooting on live `/etc/kubernetes/manifests`

Tier 2 and Tier 3 topics may only appear as clearly labeled bridge/simulation tasks (see Bridge Tasks section). They must never be presented as live tasks on the current backend.

## Jumphost Security Toolbox

These tools are installed on the jumphost (`ckad9999`) and can be used directly in questions:

| Tool | Pinned version | Typical CKS use |
| --- | --- | --- |
| trivy | 0.71.0 | image/filesystem/config vulnerability scanning |
| kube-bench | 0.15.6 | CIS benchmark output analysis (planted output on k3d) |
| kubesec | 2.14.2 | manifest security scoring |
| cosign | 3.1.1 | signature verification against planted keys/artifacts |
| syft | 1.45.1 | SBOM generation and analysis |
| etcdctl | 3.6.12 | etcd command preparation, snapshot file inspection (bridge only on k3d) |
| yq | 4.53.3 | YAML inspection and surgical edits |

Also available: kubectl, helm, jq, docker.

Tool-based questions should produce a verifiable artifact (a report file, a filtered finding list, a fixed manifest) so validation can check positive end state, not just that the tool ran.

## Trigger Mapping and Naming Rules

Map common user prompts to lab names and defaults unless the user gives a custom title.

### Full CKS Mock

User:

```text
Create CKS mock exam -1
```

Generate:

- Name: `Mock Exam - CKS -1`
- Category: `CKS`
- Duration: 120 minutes
- Question count: 16
- Difficulty: Hard
- Domain coverage: all six CKS domains at official weights

### Topic Practice

User:

```text
Create a CKS practice set for Supply Chain Security for 1 hr
```

Generate:

- Name: `Practice Question - CKS Supply Chain Security -1`
- Duration: 60 minutes
- Question count: 7 to 9
- Difficulty: Hard
- Focus: trivy, syft, cosign, image policy, registry restrictions, Dockerfile/manifest review

### PDF or Custom Source

If the user provides a PDF or custom notes and asks to use only that source:

- Use only the provided material.
- Do not browse for question content.
- Transform concepts into original CK-X CKS-style tasks.
- Add source coverage notes in the final report.

If the source is missing or inaccessible, ask for the file before generating.

## Repository Inspection Workflow

Before creating or changing a lab:

1. Confirm the CK-X repository root (contains `.git`, `docs`, `facilitator`, `jumphost`, `nginx`, `remote-desktop`, `remote-terminal`).
2. Locate the active registry: prefer `facilitator/assets/exams/labs.json`; fall back to `lab.json` or root-level registry only if absent.
3. Confirm the registry contains a top-level `labs` array.
4. Back up the registry before modifying it.
5. Scan existing CKS folders under `facilitator/assets/exams/cks/`.
6. Choose the next unused zero-padded folder unless the user gives an explicit ID.
7. Never overwrite an existing numeric lab folder without explicit user confirmation.
8. If folder/registry mismatch is found, stop and report it.
9. Inspect previous CKS `assessment.json` and `answers.md` files to avoid repeating scenarios, object names, and failure modes.
10. Do not modify unrelated app, backend, Docker, cluster, desktop, or terminal files during lab generation.

## Lab Location and Structure

Generated CKS labs must be written only under:

```text
facilitator/assets/exams/cks/NNN/
```

Required structure:

```text
facilitator/assets/exams/cks/NNN/
|-- config.json
|-- assessment.json
|-- answers.md
`-- scripts/
    |-- setup/
    |   |-- q1_setup.sh
    |   `-- ...
    `-- validation/
        |-- q1_s1_validate_name.sh
        `-- ...
```

Do not commit `assets.tar.gz`. It is generated automatically by the facilitator at runtime.

## Registry Rules

Active registry: `facilitator/assets/exams/labs.json`.

- Registry ID format: `cks-NNN`.
- `assetPath` format: `assets/exams/cks/NNN`.
- `category`: `CKS`.
- `warmUpTimeInSeconds`: `360` for full mocks and hard labs; `260` for smaller practice sets.
- `examDurationInMinutes`: based on the request (120 for full mocks).
- `difficulty`: normally `Hard`.
- Preserve all existing registry entries. Keep JSON valid.

Example:

```json
{
  "id": "cks-NNN",
  "assetPath": "assets/exams/cks/NNN",
  "name": "Mock Exam - CKS -N",
  "category": "CKS",
  "description": "Original CKS-style mock exam covering cluster setup, hardening, microservice security, supply chain security, and runtime security.",
  "warmUpTimeInSeconds": 360,
  "difficulty": "Hard",
  "examDurationInMinutes": 120
}
```

## config.json Rules

```json
{
  "lab": "cks-NNN",
  "workerNodes": 2,
  "answers": "assets/exams/cks/NNN/answers.md",
  "questions": "assessment.json",
  "totalMarks": 100,
  "lowScore": 40,
  "mediumScore": 60,
  "highScore": 90
}
```

- `lab` must match the registry `id`.
- `totalMarks` must be `100`.
- `answers` path must match the lab folder.

## assessment.json Rules

Top-level shape: `{ "questions": [] }`.

Each question must include:

- `id` as a sequential string: `"1"`, `"2"`, ...
- `namespace`.
- `machineHostname`: `ckad9999`.
- `question` with exact names, namespaces, images, labels, ports, paths, and expected end state in backticks.
- `concepts` (used for weak-area tracking — use consistent security concept names like `network policies`, `rbac`, `pod security admission`, `seccomp`, `image scanning`, `sbom`, `supply chain`, `audit logs`, `secrets`).
- `verification` with 2 to 5 entries.

Verification object:

```json
{
  "id": "1",
  "description": "outcome-focused validation description",
  "verificationScriptFile": "q1_s1_validate_name.sh",
  "expectedOutput": "0",
  "weightage": 4
}
```

- Hard troubleshooting/hardening tasks should normally have 3 to 5 validation steps.
- Total validation weightage across the lab must equal exactly `100`.

## Weight Distribution Rules

Total assessment weight must equal exactly `100`.

Practical full-mock splits:

- 16 questions: 12 questions x 6 marks = 72, 4 questions x 7 marks = 28, total 100.
- 15 questions: 10 questions x 7 marks = 70, 5 questions x 6 marks = 30, total 100.
- 17 questions: 15 questions x 6 marks = 90, 2 questions x 5 marks = 10, total 100.
- 18 questions: 10 questions x 6 marks = 60, 8 questions x 5 marks = 40, total 100.

Give the higher per-question marks to the most security-critical, multi-step questions. Inside each question, split marks across 2 to 5 validation scripts using integer weights.

## Setup Script Rules

Setup scripts:

- live under `scripts/setup/`, named `q1_setup.sh`, `q2_setup.sh`, ...
- start with `#!/bin/bash` and use `set -euo pipefail` unless there is a reason not to.
- are non-interactive and idempotent (safe to run twice).
- create namespaces with `kubectl create namespace ... --dry-run=client -o yaml | kubectl apply -f -`.
- create the BROKEN or insecure initial state for hardening/troubleshooting tasks (overprivileged RBAC, missing NetworkPolicy, privileged pod spec, unsigned image reference, vulnerable manifest, planted audit log, planted kube-bench output).
- create `/tmp/exam/qN` working directories and planted artifacts when needed.
- clean only resources owned by that question; never global cleanup.
- must not make any validation pass before candidate work.

For Tier 1 tool tasks, setup plants the input artifacts (manifests to scan, images to reference, keys for cosign, log files for analysis).

## Validation Script Rules

Validation scripts:

- live under `scripts/validation/`, named `qN_sM_validate_name.sh`.
- start with `#!/bin/bash`, are deterministic and non-interactive.
- return `0` only when expected end state is achieved; non-zero otherwise.
- check real cluster state or real artifact content, one meaningful aspect per script.

Anti-false-positive rules (mandatory):

- No validation may pass on the freshly broken setup state. If setup runs and validation immediately passes, the validation is wrong.
- Every question needs at least one positive end-state check (object exists with exact fields, workload Ready, file contains required content).
- Do not award marks only because something dangerous is absent or deleted.
- Do not award marks only because a setup-created namespace exists.

Security-specific validation patterns:

- RBAC: check the Role/Binding spec AND effective authorization with `kubectl auth can-i` for both the allowed action (must be yes) and a denied action (must be no), where practical.
- NetworkPolicy: check policy structure AND, where possible, actual connectivity (allowed path works, denied path fails).
- Pod Security Admission: check namespace labels AND that a violating pod is actually rejected (capture rejection) AND that a compliant pod runs.
- SecurityContext/seccomp: check exact field paths AND that the pod is Running.
- Tool tasks (trivy/kubesec/cosign/syft): check the output artifact exists AND contains required findings/fields (e.g., specific CVE ID present, score above threshold, signature verified string), not merely that a file exists.
- Audit-log analysis: check the candidate's extracted answer file content against the planted log's known facts.
- Admission policy (VAP/Gatekeeper/Kyverno): check policy object exists AND a violating resource is rejected AND a compliant resource is accepted.

Good validation skeleton:

```bash
#!/bin/bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

NS="cks-q01"

kubectl -n "$NS" get networkpolicy deny-egress >/dev/null 2>&1 || fail "NetworkPolicy missing"
# ... positive end-state checks ...
pass "NetworkPolicy correctly restricts egress"
```

## Bridge Tasks (Tier 2 / Tier 3 Topics)

Bridge tasks are allowed only for Tier 2/Tier 3 topics and must not dominate a mock (at most ~2-3 of 16 questions unless the user explicitly asks for kubeadm/runtime-security drill practice).

Bridge task wording must clearly say:

- this is simulated.
- do not execute destructive commands.
- work against artifacts under `/tmp/exam/qN/` (copied manifests, sample configs, planted logs, sample certs).
- validation checks files, scripts, copied artifacts, or safe diagnostics.

Allowed bridge patterns:

- API server flag hardening: fix a COPIED kube-apiserver manifest under `/tmp/exam/qN/`; validate the file.
- Audit policy: write an audit policy YAML to a file matching stated requirements; validate the file content.
- EncryptionConfiguration: write the config file and the etcdctl verification commands to a script; validate file content and script syntax.
- kube-bench remediation: analyze planted kube-bench output, write remediation steps/fixed config files; validate the files.
- Falco rules: write a Falco rule file matching stated detection requirements; validate the rule file structure (clearly labeled as not running).
- AppArmor: write a profile file and the pod annotation/field into a manifest file; validate files (clearly labeled as not enforced).
- gVisor: write a RuntimeClass manifest and pod spec referencing it to files; validate files (clearly labeled as not runnable).

## answers.md Rules

- One heading per question.
- Short root-cause/goal explanation.
- Direct commands and/or YAML, copy-paste friendly.
- Verification commands the candidate can run.
- For capture-the-error tasks, show the exact redirection pattern, e.g. `kubectl apply -f - > /tmp/violation.txt 2>&1 <<EOF`.

## Question History and Duplicate Avoidance

- Inspect previous CKS `assessment.json` and `answers.md` files before generating.
- Avoid repeating exact object names, namespaces, failure modes, or scenarios from cks-001 and later labs.
- Maintain `facilitator/assets/exams/cks/question-history.json` if it exists; create it when generating new labs if useful.

## Mandatory Validation Before Final Response

From the repository root:

```bash
git diff --check
python3 -m json.tool facilitator/assets/exams/labs.json >/dev/null
python3 -m json.tool facilitator/assets/exams/cks/NNN/config.json >/dev/null
python3 -m json.tool facilitator/assets/exams/cks/NNN/assessment.json >/dev/null
find facilitator/assets/exams/cks/NNN/scripts -type f -name '*.sh' -exec bash -n {} \;
chmod +x facilitator/assets/exams/cks/NNN/scripts/setup/*.sh facilitator/assets/exams/cks/NNN/scripts/validation/*.sh
.claude/skills/cks-exam-generator-2026/scripts/validate_ckx_cks_lab.sh facilitator/assets/exams/cks/NNN
```

Required structural checks:

- `config.json`, `assessment.json`, and `labs.json` are valid JSON.
- `config.totalMarks` equals `100` and total validation weightage equals exactly `100`.
- every question has 2 to 5 validation scripts.
- every `verificationScriptFile` and setup script exists and is executable.
- all shell scripts pass `bash -n`.
- no `assets.tar.gz` is committed.
- registry entry exists and matches the lab.
- every question uses `machineHostname: ckad9999`.
- no Tier 2/Tier 3 topic appears as a real (non-bridge) task.
- false-positive audit: reason through each validation against the freshly-setup broken state.
- write `validation-report.md` in the lab folder when generating labs.

After adding or changing lab assets, include rebuild/restart commands in the final response:

```bash
docker compose build facilitator
docker compose up -d facilitator nginx
```

Do not run `docker compose down -v` or `docker system prune`.

## Runtime Validation Ideal

If a live CK-X cluster is available:

1. Run all setup scripts.
2. Run all validations before solving — every one must fail (or the question is broken).
3. Apply the answers.md solution.
4. Run validations again — every one must pass.

If no live cluster is available, run static validation and clearly report that runtime validation was skipped.

## Final Response Format After Lab Generation

- Lab ID and display name.
- Files created or modified.
- Question count, duration, total marks, validation script count.
- Domain coverage table against official CKS weights.
- Tier classification of each question (Tier 1 real / bridge).
- Validation results and runtime validation status.
- Any assumptions.
- Rebuild/restart commands.

## When Uncertain

Ask only when required information is missing or the action could overwrite existing files. Otherwise proceed with these defaults:

- Category: `CKS`.
- Difficulty: Hard.
- Full mock: 120 minutes, 16 questions.
- Topic practice 60 minutes: 7 to 9 questions.
- Hostname: `ckad9999`.
- Worker nodes: 2.
- Total marks: 100.
- Validation scripts per question: 2 to 5.
