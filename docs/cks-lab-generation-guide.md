# CK-X CKS Lab Generation Guide for AI Tools

This guide defines how to generate original CKS (Certified Kubernetes Security Specialist) mock exams and practice labs for the CK-X Simulator in this repository.

It is the CKS counterpart of `docs/cka-lab-generation-guide.md`. Where this guide is silent, the CKA guide's repository mechanics (file layout, registry handling, script execution context) apply unchanged.

The companion Claude Code skill is `.claude/skills/cks-exam-generator-2026/`.

## Originality and Legal Boundary

All generated content must be original.

- Do not copy Killer.sh, PSI, CNCF, Linux Foundation, or real exam content.
- "Killer.sh-style" means format, rigor, timing, scoring, and review workflow only — never content.
- Do not reproduce paid training, private exam, NDA-protected, or leaked content.
- Do not claim official exam equivalence.
- User-provided legally usable notes/PDFs may be transformed into original CK-X scenarios for private practice.

## Current Repository Facts

- Backend: k3d/K3s (single cluster inside DinD container `k8s-api-server`), not kubeadm.
- Candidate machine: jumphost, hostname `ckad9999`.
- `kubectl` and `helm` work directly from the candidate shell; `KUBECONFIG` points at `/home/candidate/.kube/config` (validation runs use `/home/candidate/.kube/kubeconfig`).
- Setup and validation scripts run on the jumphost; the facilitator packages `scripts/` into `assets.tar.gz` automatically at startup. Never commit `assets.tar.gz`.
- k3s v1.31+ enforces Pod Security Admission and NetworkPolicy natively.
- Node binaries live at `/bin/kubectl` and `/bin/k3s` inside k3d nodes (no standalone kubelet binary, no `/etc/kubernetes/manifests`).

### Jumphost Security Toolbox

Installed as pinned static binaries (see `jumphost/Dockerfile`):

| Tool | Version | Use |
| --- | --- | --- |
| trivy | 0.71.0 | image/filesystem/config vulnerability scanning |
| kube-bench | 0.15.6 | CIS benchmark analysis (against planted output on k3d) |
| kubesec | 2.14.2 | manifest security scoring |
| cosign | 3.1.1 | signature verification |
| syft | 1.45.1 | SBOM generation |
| etcdctl | 3.6.12 | etcd commands (bridge/snapshot-file tasks only on k3d) |
| yq | 4.53.3 | YAML inspection and editing |

Plus kubectl, helm, jq, docker.

## Official CKS Alignment

Domain weights:

| Domain | Weight |
| --- | ---: |
| Cluster Setup | 15% |
| Cluster Hardening | 15% |
| System Hardening | 10% |
| Minimize Microservice Vulnerabilities | 20% |
| Supply Chain Security | 20% |
| Monitoring, Logging and Runtime Security | 20% |

Exam shape:

- Full mock: **16 questions, 120 minutes** by default.
- Allowed range: 15-18 questions, only when explicitly requested.
- Difficulty: **Hard** by default; Medium/Easy only when explicitly requested.
- All tasks are terminal-based, performance-based Kubernetes security tasks.

Suggested 16-question domain split: 2-3 Cluster Setup, 2-3 Cluster Hardening, 1-2 System Hardening, 3 Minimize Microservice Vulnerabilities, 3 Supply Chain Security, 3 Monitoring/Logging/Runtime Security.

## Backend Capability Matrix

Classify every question before writing it. Full matrix: `.claude/skills/cks-exam-generator-2026/references/ckx-cks-backend-capability-matrix.md`.

### Tier 1 — k3d-safe now (real runnable tasks)

- NetworkPolicy (default-deny, label-based ingress/egress, metadata blocking)
- RBAC and `kubectl auth can-i`
- ServiceAccount hardening (automount, least privilege)
- Pod Security Admission namespace labels
- SecurityContext (runAsNonRoot, capabilities, readOnlyRootFilesystem)
- seccomp `RuntimeDefault`
- ValidatingAdmissionPolicy (CEL)
- Gatekeeper/Kyverno if installed by the setup script
- Ingress TLS if an ingress controller is installed/available
- trivy/kubesec/cosign/syft static analysis tasks
- Secrets management (create, mount, find leaks, decode, rotate)
- Audit-log analysis from planted log files
- Dockerfile and manifest security review from planted files
- Binary verification with sha256sum (`kubectl`, `k3s`)

### Tier 2 — requires host capability later (bridge only)

- AppArmor
- Falco / eBPF runtime detection
- gVisor RuntimeClass

### Tier 3 — requires kubeadm backend later (bridge only)

- Real API server flag hardening
- Real audit logging configuration
- EncryptionConfiguration with etcdctl verification
- Kubelet config hardening
- kube-bench remediation against real control-plane files
- Static pod manifest troubleshooting

### Bridge Task Rules

Tier 2/Tier 3 topics may only appear as clearly labeled simulation tasks:

- Question text must say it is simulated.
- Candidate works on artifacts under `/tmp/exam/qN/` (copied manifests, sample configs, planted logs).
- Validation checks files, scripts, copied artifacts, or safe diagnostics only.
- At most ~2-3 bridge questions in a 16-question mock unless explicitly requested.
- Never create impossible real tasks on k3d.

## Lab Location and Registry

- New CKS labs go under `facilitator/assets/exams/cks/NNN/` (next unused zero-padded number).
- Registry: `facilitator/assets/exams/labs.json` (back it up before modifying).
- Registry ID `cks-NNN`, assetPath `assets/exams/cks/NNN`, category `CKS`.
- `warmUpTimeInSeconds`: 360 for full mocks/hard labs, 260 for smaller sets.
- Never overwrite an existing lab folder without explicit confirmation.

Required lab structure:

```text
facilitator/assets/exams/cks/NNN/
|-- config.json          (lab id, totalMarks: 100, answers path, workerNodes)
|-- assessment.json      (questions with machineHostname: ckad9999)
|-- answers.md           (full solutions)
`-- scripts/
    |-- setup/qX_setup.sh
    `-- validation/qX_sY_validate_name.sh
```

## Scoring Rules

- Total validation weightage must equal exactly **100**.
- Each question: 2 to 5 validation scripts; hard hardening/troubleshooting questions normally 3 to 5.
- Integer weights only.

Full-mock splits:

- 16 questions: 12 x 6 + 4 x 7 = 100.
- 15 questions: 10 x 7 + 5 x 6 = 100.
- 17 questions: 15 x 6 + 2 x 5 = 100.
- 18 questions: 10 x 6 + 8 x 5 = 100.

Give 7-mark slots to the most security-critical multi-step questions.

## Setup Script Rules

- Idempotent, non-interactive, `#!/bin/bash` with `set -euo pipefail`.
- Create namespaces with `kubectl create namespace ... --dry-run=client -o yaml | kubectl apply -f -`.
- Create the BROKEN/insecure initial state: overprivileged RBAC, missing policies, privileged pod specs, vulnerable manifests, planted audit logs, planted kube-bench output, unsigned artifacts.
- Plant tool-task inputs under `/tmp/exam/qN/`.
- Clean only resources owned by that question.
- Must not make any validation pass before candidate work.

## Validation Script Rules

- Deterministic, non-interactive; exit `0` only on solved end state.
- Every validation must check a positive final state.
- **No validation may pass on the freshly broken setup state.** If setup runs and a validation passes immediately, the validation is wrong.
- Avoid pure-negative validations (absence-of-X checks) that pass before the student does anything.

Security-specific patterns:

| Topic | Required checks |
| --- | --- |
| RBAC | object spec + `kubectl auth can-i` allowed action = yes AND a denied action = no, where practical |
| NetworkPolicy | policy structure + allowed path connects AND denied path fails, where possible |
| Pod Security Admission | namespace labels + compliant pod Running + violating pod rejected (with captured error) |
| SecurityContext/seccomp | exact field paths + pod Running |
| Admission policy (VAP/Gatekeeper/Kyverno) | policy exists + violating resource rejected + compliant resource accepted |
| Tool tasks (trivy/kubesec/cosign/syft) | output artifact exists + contains required findings (CVE IDs, score thresholds, verified strings) |
| Audit-log analysis | candidate's answer file matches the planted log's known facts |
| Secrets | secret content + mount/env exposure + rotated value where applicable |

## answers.md Rules

- One heading per question; short root-cause/goal line; copy-paste-ready commands and YAML; verification commands.
- For error-capture tasks use the proven pattern:

```bash
kubectl apply -f - > /tmp/violation.txt 2>&1 <<EOF
...yaml...
EOF
```

(Do not use `| tee` with a heredoc — it captures the YAML, not the error.)

## Generation Workflow

1. Inspect repository root and registry; back up `labs.json`.
2. Scan `facilitator/assets/exams/cks/` and previous CKS labs to avoid duplicate scenarios/names.
3. Plan domain split and tier classification per question.
4. Write `config.json`, `assessment.json`, `answers.md`, setup scripts, validation scripts.
5. `chmod +x` all setup and validation scripts.
6. Update `labs.json` safely (preserve existing entries).
7. Run mandatory validation (below).
8. Write `validation-report.md` in the lab folder.

## Mandatory Validation Before Finishing

```bash
python3 -m json.tool facilitator/assets/exams/labs.json >/dev/null
python3 -m json.tool facilitator/assets/exams/cks/NNN/config.json >/dev/null
python3 -m json.tool facilitator/assets/exams/cks/NNN/assessment.json >/dev/null
find facilitator/assets/exams/cks/NNN/scripts -type f -name '*.sh' -exec bash -n {} \;
.claude/skills/cks-exam-generator-2026/scripts/validate_ckx_cks_lab.sh facilitator/assets/exams/cks/NNN
```

The validator checks: valid JSON, totalMarks 100, weightage exactly 100, 2-5 validations per question, all referenced scripts exist and are executable, no orphan validation scripts, `machineHostname: ckad9999`, no committed `assets.tar.gz`, registry entry matches, and warns on Tier 2/Tier 3 topics that lack bridge/simulation markers.

Then run a manual false-positive audit: for each validation script, reason through whether it could pass against the freshly-setup broken state.

## Runtime Validation Ideal

With a live CK-X stack:

1. Run all setup scripts.
2. Run all validations — every one must fail.
3. Apply the answers.md solutions.
4. Run all validations — every one must pass.

If no live cluster is available, do static validation and report that runtime validation was skipped.

After changing lab assets:

```bash
docker compose build facilitator
docker compose up -d facilitator nginx
```

Never run `docker compose down -v` or `docker system prune`.

## Final Checklist Before Marking A Lab Ready

- [ ] All content original; no Killer.sh/PSI/CNCF/LF/real-exam content.
- [ ] Question count: 16 default (15-18 only when explicitly requested), 120 minutes for full mocks.
- [ ] Total weightage exactly 100; 2-5 validations per question.
- [ ] Hard difficulty unless explicitly requested otherwise.
- [ ] Domain coverage matches official CKS weights.
- [ ] Every question Tier-classified; Tier 2/3 only as labeled bridge tasks.
- [ ] `machineHostname: ckad9999` on every question.
- [ ] Setup scripts idempotent; no validation passes on fresh setup state.
- [ ] RBAC/policy validations test allowed AND denied behavior where practical.
- [ ] All scripts executable and pass `bash -n`.
- [ ] `labs.json` updated and backed up; no `assets.tar.gz` committed.
- [ ] `validation-report.md` written.
- [ ] Skill validator passes: `validate_ckx_cks_lab.sh`.
