---
name: cka-exam-generator-2026
version: 8.0.0
license: MIT
description: Repository-native CK-X Simulator lab generator for original, high-quality CKA 2026 mock exams, topic practice sets, single practice questions, and safe bridge labs for kubeadm-only topics. Use when the user asks to create or review CKA mock exams, revision exams, RBAC labs, workloads labs, networking labs, troubleshooting labs, storage labs, Helm labs, weak-area practice, or PDF/custom-source CKA question sets.
metadata:
  author: Leo
  target: Claude Code
  project: CK-X-Exam-Simulator
  category: Kubernetes CKA exam generation
---

# CKA Exam Generator 2026 for CK-X

## Mission

Generate and maintain high-quality CK-X Simulator CKA lab packages inside the user's repository. The goal is original CKA/Killer.sh-grade practice quality: serious Kubernetes administration scenarios first, then practical adaptation so the tasks are runnable and gradable inside CK-X.

CK-X is the execution and validation platform. It is not the quality ceiling. Generated questions should be realistic, troubleshooting-heavy, multi-step, exact, time-pressured, and validated by real end state wherever the current CK-X backend supports it.

Questions should feel like serious CKA/Killer.sh-grade admin scenarios: troubleshooting-heavy, multi-step, exact, time-pressured, and validated by real end state. Avoid toy create-only tasks unless the user explicitly asks for beginner/easy practice.

This skill is repository-native for Claude Code. When the user asks to generate a lab, create or update files directly in the repository after inspecting the current CK-X structure and confirming only when an overwrite or risky decision is involved.

## Legal, Originality, and Safety Boundary

Generate original Killer.sh-grade scenarios. Do not copy Killer.sh.

Hard boundaries:

- Do not copy, scrape, leak, or reproduce real CKA exam tasks.
- Do not copy, scrape, leak, or reproduce Killer.sh tasks.
- Do not reproduce paid training, private exam, NDA-protected, or leaked content.
- Do not claim generated content is official CNCF, Linux Foundation, PSI, Kubernetes, Killer.sh, or real exam content.
- If the user provides legally usable notes, PDFs, or custom material, transform the concepts into original CK-X scenarios for private practice.
- Do not copy source material word-for-word unless the user explicitly owns it and asks for exact preservation.
- Do not claim official exam equivalence.

Safe rewrite example:

- Unsafe request: "Copy Killer.sh questions into CK-X."
- Safe response: "Create original Killer.sh-grade CKA troubleshooting scenarios with similar difficulty and topic coverage, without copying wording, structure, object names, or paid/private content."

## Official-Style CKA Alignment

Use the public CKA domain model and performance-based command-line style.

Default exam shape:

- Full CKA mock duration: 120 minutes.
- Full mock default question count: 17.
- Realistic full mock range: 17 to 19 questions.
- 25 questions only when explicitly requested.
- Difficulty default: Medium-to-Hard.
- Do not generate Easy questions unless explicitly requested.
- Questions must be performance-based command-line Kubernetes administration tasks.

Use these domain weights:

| Domain | Weight |
| --- | ---: |
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Services & Networking | 20% |
| Storage | 10% |
| Troubleshooting | 30% |

Troubleshooting should appear throughout the exam, not only as isolated final questions.

If the user asks for latest official syllabus confirmation and internet access is available, verify against official CNCF/Linux Foundation/Kubernetes sources before generation. If internet is unavailable, use the domain model above and report that official-source verification was not performed.

## Trigger Mapping and Naming Rules

Map common user prompts to lab names and defaults unless the user gives a custom title.

### Revision Mock Exam

User:

```text
Create mock exam for revision -1 all CKA exam topic
```

Generate:

- Name: `Mock Exam - CKA revision -1`
- Category: `CKA`
- Duration: 120 minutes
- Question count: 17 by default
- Difficulty: Medium-to-Hard
- Domain coverage: all CKA domains

### Hard Revision Mock

User:

```text
Create mock exam for revision -2 all CKA exam topic with difficulty level Hard
```

Generate:

- Name: `Mock Exam - CKA revision -2`
- Category: `CKA`
- Duration: 120 minutes
- Question count: 17 by default
- Difficulty: Hard
- Domain coverage: all CKA domains

If the user writes "dually level", treat it as "difficulty level".

### Topic Practice

User:

```text
Create a practice question set for Cluster Troubleshooting for 2 hrs exam
```

Generate:

- Name: `Practice Question - Cluster Troubleshooting -1`
- Duration: 120 minutes
- Question count: 17 by default
- Focus: troubleshooting-heavy cluster operations with supporting workloads, services, networking, storage, RBAC, logs, events, and kubeconfig tasks

### Helm Practice

User:

```text
Create a practice question set for Helm practice question for 1 hrs
```

Generate:

- Name: `Practice Question - Helm - 1`
- Duration: 60 minutes
- Question count: 8 to 10 by default
- Include install, upgrade, rollback, values override, namespace, failed release, chart rendering, and generated Kubernetes object troubleshooting.
- Avoid external chart dependencies unless setup provides a local chart or a tested reachable repo.

### PDF or Custom Source

If the user provides a PDF or custom notes and asks to use only that source:

- Use only the provided material.
- Do not browse for question content.
- Do not copy word-for-word unless the user explicitly owns the material and asks for exact preservation.
- Prefer transforming concepts into original CK-X CKA-style tasks.
- Add source coverage notes in the final report.

If the source is missing or inaccessible, ask for the file before generating.

## Repository Inspection Workflow

Before creating or changing a lab, Claude Code must inspect the repository.

1. Confirm the CK-X repository root.
   - The root should contain `.git`, `app`, `docs`, `facilitator`, `jumphost`, `kind-cluster`, `nginx`, `remote-desktop`, and `remote-terminal`.
   - If Claude Code is not running from the repository root, stop and ask the user to reopen from the CK-X root.

2. Locate the active registry in this order:
   - `facilitator/assets/exams/labs.json`
   - `facilitator/assets/exams/lab.json`
   - `labs.json`
   - `lab.json`

3. Prefer `facilitator/assets/exams/labs.json` if multiple registry files exist.

4. Confirm the registry contains a top-level `labs` array.

5. Scan existing CKA folders under:

```text
facilitator/assets/exams/cka/
```

6. Scan existing lab IDs in the registry.

7. Choose the next unused zero-padded folder unless the user gives an explicit ID.

8. Never overwrite an existing numeric lab folder without explicit user confirmation.

9. If a folder exists but the registry entry is missing, stop and report the mismatch.

10. If a registry entry exists but the folder is missing, stop and report the mismatch.

11. Inspect previous `assessment.json` and `answers.md` files when relevant to avoid repetition.

12. Do not modify unrelated app, backend, Docker, cluster, desktop, terminal, or generated-lab files during a normal lab-generation task.

## Current CK-X Simulator Facts

Use these facts when generating labs for the current repository:

- Current backend is k3d/K3s, not a real kubeadm cluster.
- Candidate hostname is `ckad9999`.
- `ssh controlplane`, `ssh node01`, and `ssh node02` are helper workflows into simulated node containers.
- Plain `kubectl` works from the candidate shell.
- Setup and validation scripts run on the jumphost.
- `KUBECONFIG` should use `/home/candidate/.kube/config` or `/home/candidate/.kube/kubeconfig` as appropriate.
- Attempt history and weak-area reporting depend on lab metadata, concepts, scores, failed questions, and failed validation steps.
- `assets.tar.gz` is generated automatically by the facilitator at runtime. Do not commit it.

Current-backend tasks must not require real kubeadm internals.

Do not generate these as real current-backend tasks:

- real kubeadm upgrade
- real kubeadm init
- real kubeadm join
- real kubeadm certificate renewal
- real etcd restore of live control plane
- real editing of live `/etc/kubernetes/manifests`
- real kubeadm control-plane component repair
- real container runtime migration
- real multi-control-plane HA setup

## Lab Location and Structure

Generated CKA labs must be written only under:

```text
facilitator/assets/exams/cka/NNN/
```

The repository may already contain CKA folders such as `001`, `002`, `003`, `004`, and `007`. For a new CKA lab, scan `facilitator/assets/exams/cka/` and choose the next unused zero-padded folder, for example `005`, unless the user explicitly gives a lab ID. Never overwrite an existing numeric lab folder without explicit confirmation.

Required structure:

```text
facilitator/assets/exams/cka/NNN/
|-- config.json
|-- assessment.json
|-- answers.md
`-- scripts/
    |-- setup/
    |   |-- q1_setup.sh
    |   |-- q2_setup.sh
    |   `-- ...
    `-- validation/
        |-- q1_s1_validate_name.sh
        |-- q1_s2_validate_name.sh
        `-- ...
```

Do not commit:

```text
assets.tar.gz
```

## Registry Rules

Active registry:

```text
facilitator/assets/exams/labs.json
```

Rules:

- Registry ID format: `cka-NNN`.
- `assetPath` format: `assets/exams/cka/NNN`.
- `category`: `CKA`.
- `warmUpTimeInSeconds`: use `260` for medium/smaller labs and `360` for hard/full mock exams.
- `examDurationInMinutes`: based on the request.
- `difficulty`: `Easy`, `Medium`, or `Hard`.
- Preserve all existing registry entries.
- Keep JSON valid.

Example:

```json
{
  "id": "cka-NNN",
  "assetPath": "assets/exams/cka/NNN",
  "name": "LAB_DISPLAY_NAME",
  "category": "CKA",
  "description": "Original CKA-style mock exam covering cluster operations, workloads, networking, storage, RBAC, and troubleshooting.",
  "warmUpTimeInSeconds": 360,
  "difficulty": "Hard",
  "examDurationInMinutes": 120
}
```

## config.json Rules

Create:

```json
{
  "lab": "cka-NNN",
  "workerNodes": 2,
  "answers": "assets/exams/cka/NNN/answers.md",
  "questions": "assessment.json",
  "totalMarks": 100,
  "lowScore": 40,
  "mediumScore": 60,
  "highScore": 90
}
```

Rules:

- `lab` must match the registry `id`.
- `totalMarks` must be `100`.
- `questions` must be `assessment.json`.
- `answers` path must match the lab folder.
- `workerNodes` normally should be `1` or `2`.
- Use `2` workers for realistic scheduling, networking, DaemonSet, topology, and troubleshooting practice unless resource constraints require `1`.

## assessment.json Rules

Top-level shape:

```json
{
  "questions": []
}
```

Each question must include:

- `id` as a sequential string: `"1"`, `"2"`, `"3"`.
- `namespace`.
- `machineHostname` normally `ckad9999`.
- `question`.
- `concepts`.
- `verification`.

Question rules:

- Use exact names, namespaces, images, labels, ports, paths, and expected end state.
- Use backticks for object names, commands, namespaces, image tags, ports, and paths.
- Do not include estimated time in question text.
- Concepts must be useful for weak-area tracking.
- Each question should have 2 to 5 validation steps.
- Hard troubleshooting tasks should normally have 3 to 5 validation steps.
- Total validation weightage across the lab must equal exactly `100`.

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

Verification rules:

- `id` must be a string.
- `verificationScriptFile` must exist in `scripts/validation/`.
- `expectedOutput` should be `"0"`.
- `weightage` must be a positive integer.
- Avoid meaningless tiny checks.
- Include positive end-state validation.

## Weight Distribution Rules

Always set total assessment weight to exactly `100`.

Practical scoring examples:

- 17-question full mock: 15 questions x 6 marks = 90, 2 questions x 5 marks = 10, total 100.
- 18-question mock: 10 questions x 6 marks = 60, 8 questions x 5 marks = 40, total 100.
- 19-question mock: 5 questions x 6 marks = 30, 14 questions x 5 marks = 70, total 100.
- 25-question set: 25 questions x 4 marks = 100, only when explicitly requested.

Inside each question:

- Split marks across 2 to 5 validation scripts.
- Use integer weights only.
- Prefer meaningful checks over many tiny checks.
- Include at least one positive end-state validation.

## Question History and Duplicate Avoidance

When generating new labs:

- Inspect previous `assessment.json` and `answers.md` files when relevant.
- Avoid repeating exact object names, namespaces, failure modes, or scenarios.
- Maintain or update `facilitator/assets/exams/cka/question-history.json` if it already exists.
- If `question-history.json` does not exist, it may be created when generating new labs if useful.
- Record lab name, lab ID, domain, key tasks, resource names, and troubleshooting patterns.
- Do not repeat exact scenarios unless the user explicitly asks for review repetition.

## Domain-Specific Generation Guide

### Cluster Architecture, Installation & Configuration

Generate practical tasks involving:

- RBAC.
- kubeadm workflow concepts.
- cluster lifecycle.
- control-plane awareness.
- Helm and Kustomize.
- CRDs/operators where reasonable.
- CNI/CSI/CRI concepts through symptoms.
- certificate and kubeconfig troubleshooting.

For the current k3d/K3s backend, kubeadm-only work must be simulated honestly unless the future kubeadm backend is available.

### RBAC and Security

Generate tasks involving:

- Roles, RoleBindings, ClusterRoles, ClusterRoleBindings.
- ServiceAccounts and workload ServiceAccount assignment.
- `kubectl auth can-i`.
- `pods/log`.
- `deployments/scale`.
- `resourceNames`.
- least privilege.
- removing overbroad permissions.
- kubeconfig contexts/users/clusters.
- CSRs and certificate signing flow where supported.
- imagePullSecrets.
- ServiceAccount token automount hardening.
- `securityContext`.
- `runAsNonRoot`.
- `readOnlyRootFilesystem`.
- capabilities drop.
- Pod Security Admission labels.
- NetworkPolicy security controls.

### Workloads and Scheduling

Generate tasks involving:

- Deployments, ReplicaSets, StatefulSets, DaemonSets.
- Jobs and CronJobs.
- rollouts and rollbacks.
- probes.
- lifecycle hooks.
- ConfigMaps and Secrets.
- resource requests and limits.
- `nodeSelector`.
- affinity and anti-affinity.
- taints and tolerations.
- PriorityClass.
- scheduling failures.

### Services and Networking

Generate tasks involving:

- Services.
- selectors.
- ports and targetPorts.
- Endpoints and EndpointSlices.
- DNS.
- CoreDNS symptoms.
- NetworkPolicy ingress and egress.
- Ingress or Gateway API only if simulator support is confirmed.
- service-to-pod reachability troubleshooting.

### Storage

Generate tasks involving:

- StorageClasses.
- PersistentVolumes.
- PersistentVolumeClaims.
- binding failures.
- `storageClassName` mismatch.
- accessModes and capacity mismatch.
- reclaimPolicy.
- volume mounts.
- permissions.
- StatefulSet `volumeClaimTemplates`.
- hostPath only for simulator-contained labs.

### Troubleshooting

Generate tasks involving:

- Pending Pods.
- CrashLoopBackOff.
- ImagePullBackOff.
- failed rollouts.
- failed probes.
- Service and DNS failures.
- PVC binding issues.
- node readiness symptoms where accessible.
- logs and events.
- kubeconfig and certificate failures.
- etcd backup command preparation only unless kubeadm backend exists.

### Helm

Generate tasks involving:

- repo add/update.
- install into namespace.
- override values with `--set` or values file.
- upgrade and rollback.
- troubleshoot failed release.
- `helm template`.
- validate generated Kubernetes objects.
- avoid external chart dependencies unless setup provides a local chart or repo is reachable.

## Bridge Labs For kubeadm-Only Topics Before kubeadm Backend Exists

Bridge labs are allowed only for unsupported kubeadm-only areas. They must not dominate normal full CKA mock exams unless the user explicitly asks for kubeadm maintenance practice.

For normal full CKA mocks on the current k3d backend, prefer real runnable tasks:

- RBAC.
- workloads.
- scheduling.
- services.
- DNS.
- NetworkPolicy.
- storage.
- kubeconfig.
- logs/events.
- practical troubleshooting.

Allowed bridge patterns:

- kubeadm upgrade v1.35.x to v1.36.x as script/runbook only.
- static pod manifest troubleshooting using copied manifests under `/tmp/exam/...`.
- kubelet configuration troubleshooting using copied config/log artifacts.
- etcd snapshot/restore as command/runbook practice only.
- certificate inspection/renewal as sample cert/output analysis only.
- node drain/cordon/uncordon as real kubectl practice where safe.
- worker node join troubleshooting as simulated command/log repair only.
- control-plane component troubleshooting as simulated manifests/logs only.
- audit/logging-oriented CKS as simulated until kubeadm API server flags exist.

Bridge task wording must clearly say:

- this is simulated.
- do not execute destructive commands.
- repair or write artifacts under `/tmp/exam/qN/`.
- validation checks files, copied manifests, scripts, logs, or safe diagnostics.

Bridge labs should be used to fill the gap for exam preparation, not to pretend the current backend is kubeadm.

## 30-Day CKA Preparation Recommendation

Before the user's CKA exam, do not implement the kubeadm backend. Generate only bridge labs for kubeadm-only topics and real labs for supported k3d/K3s topics.

Priority:

1. Real kubectl troubleshooting labs.
2. RBAC, scheduling, services, networking, storage.
3. Simulated kubeadm upgrade runbook/script labs.
4. Simulated etcd, static pod, kubelet, and certificate artifact labs.

Avoid spending exam-preparation time on Docker/systemd/kubeadm backend engineering.

High-score current-backend focus:

- Troubleshooting across workloads and services.
- Services, DNS, NetworkPolicy, and endpoint repair.
- RBAC and ServiceAccount least privilege.
- Scheduling with taints, tolerations, affinity, requests, and labels.
- Storage with PVC/PV binding, StorageClass mismatch, and mounts.
- kubectl speed drills using `jsonpath`, `custom-columns`, events, and logs.

Recommended mix before kubeadm backend exists:

```text
70% real supported k3d/K3s labs
20% real kubectl speed/reporting drills
10% simulated kubeadm-only bridge labs
```

## Setup Script Rules

Setup scripts:

- live under `scripts/setup/`.
- are named `q1_setup.sh`, `q2_setup.sh`, etc.
- start with `#!/bin/bash`.
- use `set -euo pipefail` unless there is a reason not to.
- are non-interactive.
- are idempotent.
- create required namespaces using `kubectl create namespace ... --dry-run=client -o yaml | kubectl apply -f -`.
- clean only resources owned by that question.
- create broken or incomplete initial state for troubleshooting tasks.
- create `/tmp/exam/qN` working directories when needed.
- avoid destructive global cleanup.
- avoid deleting unrelated namespaces or cluster resources.
- avoid sleeps unless necessary.
- use timeout loops instead of blind sleeps.
- keep setup output short.
- must not make all validations pass before candidate work.

Good setup skeleton:

```bash
#!/bin/bash
set -euo pipefail

NS="cka-q01"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q1
rm -f /tmp/exam/q1/*

kubectl -n "$NS" delete deployment q1-api --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" create deployment q1-api --image=nginx:1.25 --replicas=2

echo "Question 1 setup complete"
```

## Validation Script Rules

Validation scripts:

- live under `scripts/validation/`.
- start with `#!/bin/bash`.
- use `set -euo pipefail` unless intentional failure handling is needed.
- are deterministic and non-interactive.
- return `0` only when expected end state is achieved.
- return non-zero on unsolved state.
- check real cluster state where possible.
- check one meaningful part of the answer.
- print useful success/failure output.
- avoid false positives.

False-positive prevention:

- Do not award marks only because a dangerous permission is absent.
- Do not award marks only because an object is missing.
- Do not award marks only because setup-created namespace exists.
- Always include required positive end-state checks.
- For RBAC, check object spec and effective authorization with `kubectl auth can-i`.
- For networking, check selectors/policies and connectivity or endpoints when possible.
- For workloads, check desired spec and Ready/Available state.
- For storage, check binding and mount/use behavior.
- For file tasks, check file exists, exact content patterns, and executable bit if needed.
- For security hardening, check exact field paths and workload readiness when applicable.

Good validation skeleton:

```bash
#!/bin/bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

NS="cka-q01"
NAME="q1-api"

kubectl -n "$NS" get deployment "$NAME" >/dev/null 2>&1 || fail "Deployment missing"

READY="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.status.readyReplicas}')"
[ "${READY:-0}" = "2" ] || fail "Expected 2 ready replicas, got ${READY:-0}"

pass "Deployment is ready"
```

## answers.md Rules

Create `answers.md` with:

- one heading per question.
- short root-cause explanation.
- direct commands and/or YAML.
- verification commands.
- concise copy-paste-friendly formatting.
- no unnecessary theory.

Suggested structure:

````markdown
# Answers - CKA Mock Exam - Example

## Question 1

Goal: Repair the Service selector so it points to the existing Pods.

Solution:

```bash
kubectl -n cka-q01 patch service api-svc -p '{"spec":{"selector":{"app":"api"}}}'
kubectl -n cka-q01 get endpoints api-svc
```

Why this works:

The Service had a selector that did not match the Pods. Updating the selector creates Endpoints without recreating the Deployment.
````

## Examples

Single hard CKA practice question request:

```text
Create one hard original CKA practice question about RBAC and ServiceAccount troubleshooting. Use CK-X current backend limitations and make it fully runnable.
```

Topic-focused practice lab request:

```text
Create a 60-minute original CKA practice lab for Services, DNS, and NetworkPolicy troubleshooting.
```

2-hour full mock exam request:

```text
Create mock exam for revision -3 all CKA exam topic with difficulty level Hard.
```

Bridge kubeadm maintenance lab request:

```text
Create a simulated kubeadm upgrade bridge lab. Do not run a real upgrade. Validate the runbook/script under /tmp/exam.
```

PDF/custom-source request:

```text
Create a practice question set from this PDF only. Transform the concepts into original CK-X CKA scenarios and include source coverage notes.
```

Forbidden unsafe request:

```text
Copy Killer.sh questions into CK-X.
```

Safe rewrite:

```text
Create original Killer.sh-grade CKA troubleshooting scenarios with similar difficulty and topic coverage, without copying wording, structure, object names, or paid/private content.
```

## Mandatory Validation Before Final Response

After generating files, run or recommend these checks from the repository root.

Basic diff check:

```bash
git diff --check
```

JSON validation:

```bash
python3 -m json.tool facilitator/assets/exams/labs.json >/dev/null
python3 -m json.tool facilitator/assets/exams/cka/NNN/config.json >/dev/null
python3 -m json.tool facilitator/assets/exams/cka/NNN/assessment.json >/dev/null
```

Shell syntax validation:

```bash
find facilitator/assets/exams/cka/NNN/scripts -type f -name '*.sh' -exec bash -n {} \;
```

If the skill validator exists, prefer:

```bash
.claude/skills/cka-exam-generator-2026/scripts/validate_ckx_lab.sh facilitator/assets/exams/cka/NNN
```

Required structural checks:

- `config.json`, `assessment.json`, and `labs.json` are valid JSON.
- `config.totalMarks` equals `100`.
- total validation weightage equals exactly `100`.
- every question has 2 to 5 validation scripts.
- every `verificationScriptFile` exists.
- every setup script exists.
- setup and validation scripts are executable.
- all shell scripts pass `bash -n`.
- no `assets.tar.gz` is committed.
- registry entry exists and matches the lab.
- every question uses `machineHostname: ckad9999`.
- no unsupported real kubeadm tasks are present on current backend.

After adding or changing lab assets, include these rebuild/restart commands in the final response:

```bash
docker compose build facilitator
docker compose up -d facilitator nginx
```

Do not run:

```bash
docker compose down -v
docker system prune
```

## Runtime Validation Ideal

If a live CK-X cluster is available:

1. Run all setup scripts.
2. Run validations before solving.
3. Confirm the complete question does not already pass.
4. Apply answer or smoke solution if safe.
5. Run validations again and confirm pass.

If no live cluster is available:

- Run static validation.
- Clearly report that runtime validation was skipped.

## Final Response Format After Future Lab Generation

After future lab generation, respond with:

- Lab ID and display name.
- Files created or modified.
- Question count and duration.
- Total marks and validation script count.
- Domain coverage summary.
- Validation results.
- Runtime validation status or skipped reason.
- Any assumptions.
- Exact command to rebuild/restart if needed.

If lab registry/assets changed, include:

```bash
docker compose build facilitator
docker compose up -d facilitator nginx
```

## When Uncertain

Ask only when required information is missing or the action could overwrite existing files. Otherwise proceed with reasonable defaults.

Use these defaults:

- Category: `CKA`.
- Difficulty: Medium-to-Hard.
- Full mock duration: 120 minutes.
- Full mock question count: 17.
- Topic practice 60 minutes: 8 to 10 questions.
- Hostname: `ckad9999`.
- Worker nodes: 2.
- Total marks: 100.
- Validation scripts per question: 2 to 5.
