# CK-X CKA Lab Generation Guide for AI Tools

This document is the source of truth for asking an AI tool such as ChatGPT,
Claude Code, Codex, or another coding agent to generate custom CKA practice labs
for this CK-X simulator repository.

Use this guide when creating:

- Single CKA practice questions.
- Topic-focused CKA practice sets.
- Full CKA mock exams.
- Troubleshooting-heavy, advanced practice labs.

This guide is intentionally stricter than the older generic lab guide in
`docs/how-to-add-new-labs.md`. The older guide is useful background, but this
file reflects the current simulator behavior and the current local project
constraints.

## Current Repository Facts

Confirmed from this repository on 2026-05-01:

- The active lab registry is `facilitator/assets/exams/labs.json`.
- CKA labs live under `facilitator/assets/exams/cka/`.
- Current CKA folders may include `001`, `002`, `003`, `004`, and `007`.
- The candidate-facing SSH target shown in the exam UI is `ckad9999`.
- New CKA questions should use `"machineHostname": "ckad9999"` unless the user
  explicitly requests a different displayed target.
- The simulator currently uses a k3d/K3s-based cluster backend, not a real
  kubeadm cluster.
- A helper exists for candidate node access:
  - `ssh controlplane`
  - `ssh node01`
  - `ssh node02`
- The helper is useful for practice workflows, but it enters simulated k3d/K3s
  node containers. It is not a full kubeadm VM.
- Plain `kubectl` works from the candidate shell using the candidate kubeconfig.
- Attempt history and weak-area reporting use the lab metadata, question
  concepts, scores, failed questions, and failed validation steps. Good concept
  names matter.
- `assets.tar.gz` is generated automatically by the facilitator entrypoint from
  each lab's `scripts/` directory. Do not manually create or commit
  `assets.tar.gz`.

## Official CKA Alignment

The CKA is a performance-based command-line exam. CNCF states that candidates
solve performance-based items in a command-line environment and have 2 hours.

Use the official CNCF CKA domain weights as the top-level topic guide:

| Domain | Weight |
| --- | ---: |
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Services & Networking | 20% |
| Storage | 10% |
| Troubleshooting | 30% |

Official source:

- https://www.cncf.io/training/certification/cka/

Important quality rule:

- Do not copy tasks from the real CKA exam.
- Do not copy Killer.sh tasks.
- Do not claim the lab is official or identical to the real exam.
- Create original, realistic, performance-based Kubernetes administration
  scenarios inspired by the public CKA curriculum.

## What "High Quality" Means

A good CK-X CKA lab should feel like a serious admin scenario, not a toy YAML
exercise.

Quality characteristics:

- The task has a clear production-style reason.
- The task is solvable from the command line with `kubectl`, shell tools, and
  standard Kubernetes knowledge.
- The object names, namespaces, images, labels, ports, paths, and required end
  state are exact.
- The setup creates realistic broken or incomplete resources.
- The validation verifies the real end state, not just whether a command was
  typed.
- Validation has both positive and negative checks when appropriate.
- The task does not require internet access during the exam unless explicitly
  designed and tested.
- The task avoids ambiguous wording.
- The task avoids brittle timing assumptions.
- The task avoids hidden dependencies on another question unless the lab is
  explicitly designed as a linked scenario.
- The answers explain the reasoning, not only the commands.

Poor-quality patterns to avoid:

- "Create a Pod named X" repeated too many times.
- Validation that only greps for a string in a file when the actual cluster
  state should be checked.
- Asking for real kubeadm upgrade, real etcd restore, or real certificate
  rotation in the current k3d backend unless it is clearly simulated.
- Asking the candidate to edit `/etc/kubernetes/pki` as if this is a kubeadm
  cluster. The current backend is k3d/K3s, so kubeadm paths are not naturally
  present.
- Reusing generic names like `test`, `app`, or `nginx` without a scenario.
- Multiple valid interpretations when only one answer will pass validation.

## Current Simulator Runtime Model

Understand this before generating labs.

### Services

The main services are:

- `nginx`: localhost-only entrypoint at `127.0.0.1:30081`.
- `webapp`: static web UI.
- `facilitator`: backend API, lab registry, exam assets, scoring, history.
- `redis`: active exam state.
- `jumphost`: candidate shell host, hostname `ckad9999`.
- `k8s-api-server`: historical service name for the Kubernetes host container.
- `remote-desktop`: noVNC desktop.
- `remote-terminal`: SSH terminal support.

### Candidate Environment

Candidate workflow:

```bash
ssh ckad9999
kubectl get nodes
kubectl get pods -A
```

Control-plane helper workflow:

```bash
ssh ckad9999
ssh controlplane
k get no
k get pods -A
```

Inside `ssh controlplane`, common aliases and completion should be available:

```bash
k get no<Tab>
k get dep<Tab>
```

Important:

- `ssh controlplane` is a practice helper into a simulated node.
- It is suitable for selected node-inspection practice.
- It is not a full kubeadm control-plane VM.

### Setup And Validation Execution Context

Setup scripts run on the `jumphost` container.

Validation scripts also run on the `jumphost` container.

Both can use `kubectl` to talk to the exam cluster through:

```bash
export KUBECONFIG=/home/candidate/.kube/config
```

The repository also maintains:

```bash
/home/candidate/.kube/kubeconfig
```

Existing backend code still uses `kubeconfig` in some places, so both paths
should remain valid.

If a validation script checks a local file path like `/tmp/exam/q1/output.txt`,
it checks the file on `ckad9999`/jumphost, not on the k3d control-plane node.

If a validation script must check the simulated control-plane node filesystem,
it must explicitly SSH to `k8s-api-server` and inspect the nested node container.
This is advanced and should be used only when needed.

Example advanced validation pattern:

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  candidate@k8s-api-server \
  "docker exec k3d-cluster-server-0 sh -lc 'test -f /some/node/path'"
```

Prefer normal `kubectl` tasks unless the user explicitly wants node-level
simulation.

## Lab Location Rules

Generated CKA labs must be written only under:

```text
facilitator/assets/exams/cka/NNN/
```

The repository may already contain CKA folders such as:

```text
facilitator/assets/exams/cka/001/
facilitator/assets/exams/cka/002/
facilitator/assets/exams/cka/003/
facilitator/assets/exams/cka/004/
facilitator/assets/exams/cka/007/
```

For a new CKA lab:

1. Scan `facilitator/assets/exams/cka/`.
2. Scan `facilitator/assets/exams/labs.json`.
3. Choose the next unused zero-padded numeric folder unless the user explicitly
   gives a lab ID.
4. With the current folder set, `005` is the next lowest unused CKA folder.
5. Never overwrite an existing numeric lab folder without explicit user
   confirmation.
6. If a folder exists but the registry entry is missing, stop and report the
   mismatch.
7. If a registry entry exists but the folder is missing, stop and report the
   mismatch.

Do not create CKA labs outside `facilitator/assets/exams/cka/`.

Do not modify existing generated labs unless the user explicitly asks for a fix.

## Required Lab File Structure

Every generated CKA lab must use this structure:

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
        |-- q1_s1_validate_<short_name>.sh
        |-- q1_s2_validate_<short_name>.sh
        |-- q2_s1_validate_<short_name>.sh
        `-- ...
```

Do not commit:

```text
assets.tar.gz
```

The facilitator creates it at container startup.

## Registry Entry Rules

Update only the active registry:

```text
facilitator/assets/exams/labs.json
```

Add one object to the `labs` array.

Example for `cka-005`:

```json
{
  "id": "cka-005",
  "assetPath": "assets/exams/cka/005",
  "name": "CKA Mock Exam - Cluster Operations and Troubleshooting",
  "category": "CKA",
  "description": "Original CKA-style mock exam covering cluster operations, workloads, networking, storage, RBAC, and troubleshooting.",
  "warmUpTimeInSeconds": 360,
  "difficulty": "Hard",
  "examDurationInMinutes": 120
}
```

Registry rules:

- `id` must match `config.json` `lab`.
- `assetPath` must match the folder.
- `category` should be `CKA`.
- `difficulty` should be one of `Easy`, `Medium`, or `Hard`.
- `examDurationInMinutes` should be realistic:
  - Single practice question: 10 to 20.
  - Topic practice set: 30 to 90.
  - Full mock exam: 120.
- `warmUpTimeInSeconds` should usually be `260` or `360`.
- Unknown categories are supported by the UI, but CKA labs should use `CKA`.

## config.json Rules

Create:

```text
facilitator/assets/exams/cka/NNN/config.json
```

Example:

```json
{
  "lab": "cka-005",
  "workerNodes": 2,
  "answers": "assets/exams/cka/005/answers.md",
  "questions": "assessment.json",
  "totalMarks": 100,
  "lowScore": 40,
  "mediumScore": 60,
  "highScore": 90
}
```

Rules:

- `lab` must equal the registry `id`.
- `workerNodes` should usually be `1` or `2`.
- Use `2` workers for scheduling, topology, networking, DaemonSet, and
  multi-node troubleshooting scenarios.
- Avoid more than `2` workers for local laptop performance unless explicitly
  approved.
- `answers` must point to this lab's `answers.md`.
- `questions` must be `assessment.json`.
- `totalMarks` must be `100`.
- Score thresholds should normally stay `40`, `60`, and `90`.

## assessment.json Rules

Create:

```text
facilitator/assets/exams/cka/NNN/assessment.json
```

Top-level shape:

```json
{
  "questions": []
}
```

Each question object must include:

```json
{
  "id": "1",
  "namespace": "cka-q01",
  "machineHostname": "ckad9999",
  "question": "Task text goes here.",
  "concepts": ["RBAC", "RoleBinding", "ServiceAccount"],
  "verification": []
}
```

Question field rules:

- `id` must be a string.
- IDs must be sequential: `"1"`, `"2"`, `"3"`.
- `namespace` should be unique for each namespaced task.
- Use `default` only for genuinely cluster-scoped tasks or if the task requires
  `default`.
- `machineHostname` must normally be `ckad9999`.
- `question` must be clear, exact, and performance-based.
- Use backticks around command names, object names, namespaces, image tags,
  ports, file paths, and literal values.
- Do not include "Estimated time" in the question text. The UI now shows
  question weight/marks.
- `concepts` must be meaningful and consistent because weak-area history uses
  these labels.
- `verification` must contain 2 to 5 validation steps.

Verification object shape:

```json
{
  "id": "1",
  "description": "Role grants only the required Pod read permissions",
  "verificationScriptFile": "q1_s1_validate_role.sh",
  "expectedOutput": "0",
  "weightage": 4
}
```

Verification rules:

- `id` must be a string.
- `verificationScriptFile` must exist in `scripts/validation/`.
- `expectedOutput` should be `"0"`.
- `weightage` must be a positive integer.
- Total weightage across all validation steps in the whole lab must equal
  exactly `100`.
- A question can have 2 to 5 validation scripts.
- Simple focused tasks usually use 2 validations.
- Hard troubleshooting tasks should normally use 3 to 5 validations.
- Full mock exams can use 20 to 25 questions with 2 to 4 validations each.
- Single-question labs must still total 100 marks, distributed across that
  question's validations.

## Concept Naming Rules

Use concepts that will be useful in the Previous Attempts weak-area summary.

Prefer consistent labels such as:

```text
RBAC
Role
RoleBinding
ClusterRole
ClusterRoleBinding
ServiceAccount
pods/log
Deployments
StatefulSets
DaemonSets
Jobs
CronJobs
scheduling
taints
tolerations
nodeSelector
affinity
resource requests
resource limits
Services
Endpoints
Ingress
NetworkPolicy
DNS
CoreDNS
StorageClass
PersistentVolume
PersistentVolumeClaim
ConfigMap
Secret
securityContext
Pod Security Admission
static pods
kubelet
etcd
backup
troubleshooting
kubectl
jsonpath
custom-columns
```

Avoid creating many near-duplicates such as:

```text
service
services
svc
Service troubleshooting
services troubleshooting
```

Pick one label style and reuse it.

## Question Count And Scoring Patterns

### Single Practice Question

Use for a focused drill.

Recommended:

- 1 question.
- 3 to 5 validation steps.
- Total weightage `100`.
- Duration 10 to 20 minutes.
- Name format: `Practice Question - <Topic> - N`.

Example weight distribution:

```text
25 + 25 + 25 + 25 = 100
```

### Topic Practice Set

Use for focused topic mastery.

Recommended:

- 5 to 12 questions.
- 2 to 4 validation steps per question.
- Total weightage `100`.
- Duration 45 to 90 minutes.
- Name format: `CKA Practice Lab - <Topic Area>`.

Example:

```text
10 questions x 2 validations x 5 marks = 100
```

### Full Mock Exam

Use for realistic exam practice.

Recommended:

- 20 to 25 questions.
- 2 to 5 validation steps per question.
- Total weightage `100`.
- Duration 120 minutes.
- Difficulty `Hard`.
- Name format: `CKA Mock Exam - <Theme>`.

Domain distribution should roughly follow the CNCF CKA weights:

```text
Cluster Architecture, Installation & Configuration: about 25 marks
Workloads & Scheduling: about 15 marks
Services & Networking: about 20 marks
Storage: about 10 marks
Troubleshooting: about 30 marks
```

Troubleshooting should be integrated across domains, not only isolated at the
end.

## Task Types That Work Well Today

These are well-supported by the current simulator:

- RBAC repair with `kubectl auth can-i`.
- ServiceAccount permission boundaries.
- Deployment rollout repair.
- Broken Service selectors and missing Endpoints.
- Readiness/liveness/startup probe fixes.
- ConfigMap and Secret mounting.
- Resource request/limit corrections.
- Scheduling with labels, taints, tolerations, node affinity.
- StatefulSet scaling and service wiring.
- Job and CronJob troubleshooting.
- NetworkPolicy ingress and egress isolation.
- PVC/PV binding and mount verification.
- Sorting, jsonpath, custom-columns, and shell output files.
- Namespace-scoped troubleshooting.
- Cluster-wide read-only reporting tasks.
- Simulated etcd backup command-writing tasks.
- Simulated static Pod manifest writing tasks.
- Control-plane helper tasks that inspect K3s/k3d node state.

## Task Types To Avoid Until kubeadm Backend Exists

Avoid these as real operational tasks in the current k3d backend:

- Real `kubeadm upgrade`.
- Real `kubeadm init` or `kubeadm join`.
- Real kubeadm certificate renewal.
- Real etcd restore of the live control plane.
- Real editing of kubeadm static Pod manifests under
  `/etc/kubernetes/manifests`.
- Real troubleshooting of kubeadm component manifests.
- Real container runtime migration.
- Real multi-control-plane HA setup.

You may create simulated versions if clearly worded and validated as command or
file-writing exercises.

Example simulated wording:

```text
Create executable script `/tmp/exam/q7/upgrade-plan.sh` containing the commands
an administrator would run to plan an upgrade from v1.32.x to v1.33.x.

The script must not execute the upgrade. It must include `kubeadm upgrade plan`
and must write output to `/tmp/exam/q7/upgrade-plan.txt`.
```

Do not phrase simulated tasks as if they are modifying a real kubeadm cluster.

## Setup Script Rules

Setup scripts live under:

```text
facilitator/assets/exams/cka/NNN/scripts/setup/
```

Naming:

```text
q1_setup.sh
q2_setup.sh
q3_setup.sh
```

Setup scripts are run on the jumphost before the exam starts:

```bash
for script in /tmp/exam-assets/scripts/setup/q*_setup.sh; do $script; done
```

Rules:

- Include one setup script per question.
- Make setup scripts idempotent.
- Use `set -euo pipefail` unless there is a specific reason not to.
- Create namespaces with `kubectl create namespace ... --dry-run=client -o yaml | kubectl apply -f -`.
- Remove previous resources with `kubectl delete ... --ignore-not-found=true`.
- Create candidate working directories under `/tmp/exam/qN`.
- Do not write to random host paths unless the question requires it.
- Avoid destructive global cleanup.
- Avoid deleting unrelated namespaces or cluster resources.
- Avoid sleeps unless truly needed.
- If waiting is required, use a timeout loop.
- Keep setup output short.

Good setup script skeleton:

```bash
#!/bin/bash
set -euo pipefail

NS="cka-q01"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q1
rm -f /tmp/exam/q1/*

kubectl -n "$NS" delete deployment q1-api --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete service q1-api --ignore-not-found=true >/dev/null 2>&1 || true

kubectl -n "$NS" create deployment q1-api --image=nginx:1.25 --replicas=2
kubectl -n "$NS" expose deployment q1-api --port=80 --target-port=80

echo "Question 1 setup complete"
exit 0
```

## Validation Script Rules

Validation scripts live under:

```text
facilitator/assets/exams/cka/NNN/scripts/validation/
```

Naming:

```text
q1_s1_validate_<short_name>.sh
q1_s2_validate_<short_name>.sh
q2_s1_validate_<short_name>.sh
```

Validation scripts are run on the jumphost during evaluation.

Rules:

- Use `#!/bin/bash`.
- Use `set -euo pipefail`.
- Return exit code `0` for pass.
- Return non-zero for fail.
- Keep output short and useful.
- Validate actual Kubernetes state whenever possible.
- Use exact namespace and exact object names.
- Do not rely on broad `grep` alone when JSONPath is safer.
- Do not mutate exam state in validation unless the validation is explicitly a
  safe permission check.
- Use temporary resources only if needed and clean them up.
- Do not store or print large command outputs.
- Avoid validations that pass if the candidate merely wrote the right words in
  a script but did not create the actual required object, unless the task is
  explicitly a command-writing task.

Good validation script skeleton:

```bash
#!/bin/bash
set -euo pipefail

fail() {
  echo "FAIL: $1"
  exit 1
}

pass() {
  echo "PASS: $1"
  exit 0
}

NS="cka-q01"
NAME="q1-api"

kubectl -n "$NS" get deployment "$NAME" >/dev/null 2>&1 || fail "Deployment $NAME not found"

IMAGE="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.spec.template.spec.containers[0].image}')"
[ "$IMAGE" = "nginx:1.25" ] || fail "Expected image nginx:1.25, got $IMAGE"

READY="$(kubectl -n "$NS" get deployment "$NAME" -o jsonpath='{.status.readyReplicas}')"
[ "${READY:-0}" = "2" ] || fail "Expected 2 ready replicas, got ${READY:-0}"

pass "Deployment $NAME is correct"
```

RBAC validation example:

```bash
#!/bin/bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

NS="cka-q02"
SA="report-reader"
AS="system:serviceaccount:${NS}:${SA}"

kubectl auth can-i get pods -n "$NS" --as="$AS" | grep -qx yes || fail "$SA cannot get pods"
kubectl auth can-i list pods -n "$NS" --as="$AS" | grep -qx yes || fail "$SA cannot list pods"
kubectl auth can-i delete pods -n "$NS" --as="$AS" | grep -qx no || fail "$SA should not delete pods"

pass "$SA has correct least-privilege access"
```

NetworkPolicy validation example:

```bash
#!/bin/bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

NS="cka-q03"
NP="allow-api-to-db"

kubectl -n "$NS" get networkpolicy "$NP" >/dev/null 2>&1 || fail "NetworkPolicy missing"

POD_SELECTOR="$(kubectl -n "$NS" get networkpolicy "$NP" -o jsonpath='{.spec.podSelector.matchLabels.role}')"
[ "$POD_SELECTOR" = "api" ] || fail "Policy must select role=api pods"

PORT="$(kubectl -n "$NS" get networkpolicy "$NP" -o jsonpath='{.spec.egress[0].ports[0].port}')"
[ "$PORT" = "5432" ] || fail "Expected egress TCP port 5432"

pass "NetworkPolicy is present with expected selector and egress port"
```

## Node-Level And Control-Plane Helper Tasks

Use these only when the user asks for node-level practice.

Candidate task wording should be explicit:

```text
SSH to the simulated control-plane node with `ssh controlplane`.
Inspect the kubelet or K3s configuration and write your finding to
`/tmp/exam/q4/result.txt` on `ckad9999`.
```

Important:

- If the final artifact is expected under `/tmp/exam/...`, ask the candidate to
  create it on `ckad9999`, not only inside `ssh controlplane`.
- If the candidate must create a file inside the simulated node, validation must
  inspect that simulated node directly.
- The current simulated control-plane is K3s/k3d, so use K3s paths when
  inspecting real node files:
  - `/etc/rancher/k3s/k3s.yaml`
  - `/var/lib/rancher/k3s/server/tls`
- Do not assume kubeadm paths exist:
  - `/etc/kubernetes/admin.conf`
  - `/etc/kubernetes/manifests`
  - `/etc/kubernetes/pki`

Advanced validation helper for simulated control-plane files:

```bash
#!/bin/bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

ssh_node() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    candidate@k8s-api-server \
    "docker exec k3d-cluster-server-0 sh -lc '$1'"
}

ssh_node "test -f /etc/rancher/k3s/k3s.yaml" || fail "K3s kubeconfig missing"

pass "Control-plane node file exists"
```

## answers.md Rules

Create:

```text
facilitator/assets/exams/cka/NNN/answers.md
```

Rules:

- Include one section per question.
- Repeat the task goal briefly.
- Provide exact commands.
- Explain why the commands work.
- Include verification commands the learner can run manually.
- If there are multiple valid solutions, mention the preferred one and why.
- Keep answers educational, not just a dump of YAML.
- Do not include secrets that are not part of the lab.
- Do not link to unofficial external sites.

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

The Service had a selector that did not match the Pods. Updating the selector
creates Endpoints without recreating the Deployment.
````

## File And Path Safety Rules

Use these paths for candidate-created files:

```text
/tmp/exam/q1/
/tmp/exam/q2/
/tmp/exam/q3/
```

Rules:

- Setup scripts may create `/tmp/exam/qN`.
- Questions should ask candidates to write reports or scripts under
  `/tmp/exam/qN`.
- Validation scripts should check those exact paths.
- Do not use `/root`, `/home/candidate` for answer artifacts unless there is a
  specific reason.
- Do not ask candidates to write outside `/tmp/exam` unless it is a deliberate
  simulated admin path.
- If asking for `/etc/kubernetes/...` in the current backend, clearly state
  whether it is a simulated file-writing task or a control-plane helper task.

## Image Selection Rules

Prefer small, common images:

```text
nginx:1.25
nginx:1.25-alpine
busybox:1.36
alpine:3.19
httpd:2.4-alpine
redis:7-alpine
registry.k8s.io/pause:3.9
```

Rules:

- Avoid unusual images unless the setup has been tested.
- Avoid tasks requiring internet browsing or package installation inside Pods.
- Prefer commands that work with BusyBox or Alpine tools.
- If an image is important to validation, validate the exact image tag.

## Full Lab Generation Workflow

An AI tool should follow this workflow:

1. Inspect `facilitator/assets/exams/cka/`.
2. Inspect `facilitator/assets/exams/labs.json`.
3. Choose the next unused CKA ID.
4. Create `facilitator/assets/exams/cka/NNN/`.
5. Create `config.json`.
6. Create `assessment.json`.
7. Create `answers.md`.
8. Create `scripts/setup/qN_setup.sh` for every question.
9. Create `scripts/validation/qN_sM_validate_<name>.sh` for every validation.
10. Update `facilitator/assets/exams/labs.json`.
11. Validate JSON.
12. Validate shell syntax.
13. Validate total weightage equals exactly `100`.
14. Validate every referenced validation script exists.
15. Validate every question uses `machineHostname: ckad9999`.
16. Validate every namespaced question has a unique namespace unless shared by
    design.
17. Validate setup scripts are idempotent.
18. Rebuild/restart only required services after user approval.

## Required Validation Commands

Use these before saying a generated lab is ready.

PowerShell JSON validation:

```powershell
node -e "const fs=require('fs'); JSON.parse(fs.readFileSync('facilitator/assets/exams/cka/NNN/config.json','utf8')); JSON.parse(fs.readFileSync('facilitator/assets/exams/cka/NNN/assessment.json','utf8')); JSON.parse(fs.readFileSync('facilitator/assets/exams/labs.json','utf8')); console.log('JSON OK')"
```

Weightage validation:

```powershell
node -e "const fs=require('fs'); const a=JSON.parse(fs.readFileSync('facilitator/assets/exams/cka/NNN/assessment.json','utf8')); const total=a.questions.flatMap(q=>q.verification).reduce((sum,v)=>sum+Number(v.weightage),0); if(total!==100){throw new Error('weightage='+total)}; console.log('weightage=100')"
```

Referenced validation script check:

```powershell
node -e "const fs=require('fs'); const p='facilitator/assets/exams/cka/NNN'; const a=JSON.parse(fs.readFileSync(p+'/assessment.json','utf8')); for(const q of a.questions){for(const v of q.verification){const f=p+'/scripts/validation/'+v.verificationScriptFile; if(!fs.existsSync(f)) throw new Error('missing '+f)}} console.log('validation scripts exist')"
```

Bash syntax check from WSL or a Linux shell:

```bash
find facilitator/assets/exams/cka/NNN/scripts -name '*.sh' -print0 | xargs -0 -n1 bash -n
```

Docker Compose validation:

```bash
docker compose config
```

After adding or changing lab assets, the facilitator must be rebuilt or
recreated because lab files are copied into the facilitator image:

```bash
docker compose build facilitator
docker compose up -d facilitator nginx
```

Do not run:

```bash
docker compose down -v
docker system prune
```

Do not delete the `attempt-history` volume.

## Manual End-To-End Test

After generating a lab:

1. Open `http://127.0.0.1:30081`.
2. Confirm the new lab appears in the dropdown.
3. Start the lab.
4. Wait until the environment is ready.
5. Confirm the exam page shows questions.
6. Confirm `ssh ckad9999` is shown.
7. In the desktop terminal, run:

```bash
kubectl get nodes
kubectl get pods -A
```

8. Solve one or two questions.
9. Submit/evaluate.
10. Confirm the score is recorded.
11. Confirm Previous Attempts shows the lab name, score, failed questions, and
    weak areas.

## AI Tool Prompt Template

Use this prompt when asking an AI tool to generate a lab.

```text
You are working in the CK-X simulator repository.

Goal:
Generate a new original CKA practice lab.

Use docs/cka-lab-generation-guide.md as the source of truth.

Hard rules:
- Generated CKA labs must be written only under facilitator/assets/exams/cka/NNN/.
- Scan facilitator/assets/exams/cka/ and facilitator/assets/exams/labs.json.
- Choose the next unused zero-padded CKA folder unless I explicitly provide an ID.
- Never overwrite an existing numeric lab folder without my explicit approval.
- Update facilitator/assets/exams/labs.json.
- Use machineHostname "ckad9999" for every question.
- Use the current k3d/K3s simulator limitations. Do not create real kubeadm upgrade, real etcd restore, or real certificate-rotation tasks unless they are clearly simulated.
- Do not copy real CKA, Killer.sh, or other paid training content.
- Create original performance-based CKA tasks aligned to the public CNCF CKA domains.
- Total validation weightage must equal exactly 100.
- Every question must have 2 to 5 validation scripts.
- Create setup scripts and validation scripts.
- Make setup scripts idempotent.
- Make validation scripts deterministic and based on actual Kubernetes state where possible.
- Do not create or commit assets.tar.gz.

Requested lab type:
<single question | topic practice set | full mock exam>

Requested focus:
<topics, difficulty, question count, duration>

Quality target:
Hard, realistic, troubleshooting-heavy CKA practice. Similar seriousness to advanced practice platforms, but original and not copied.

Before editing:
- Inspect the current CKA folders and labs.json.
- Report the chosen lab ID.

After editing:
- Run JSON validation.
- Run total weightage validation.
- Run referenced validation script validation.
- Run bash -n on scripts if available.
- Run docker compose config.
- Report files changed and any manual test steps.
```

## AI Tool Review Prompt

Use this prompt to review generated labs before testing them.

```text
Review this CK-X generated CKA lab for quality and correctness.

Use docs/cka-lab-generation-guide.md as the standard.

Check:
- Folder ID and labs.json consistency.
- config.json correctness.
- assessment.json schema correctness.
- machineHostname is ckad9999.
- Total weightage is exactly 100.
- Every question has 2 to 5 validations.
- Every validation script exists.
- Every setup script exists.
- Setup scripts are idempotent.
- Validation scripts are deterministic.
- Validation scripts check real end state, not weak string matches.
- Namespaces are isolated unless intentionally shared.
- Concepts are useful for weak-area reporting.
- No real kubeadm-only task is included for the current k3d backend unless clearly simulated.
- No copied official or paid-content scenario.
- No destructive command can delete history, volumes, generated labs, or unrelated cluster state.

Output:
- PASS/WARNING/FAIL.
- Critical fixes.
- Quality improvements.
- Exact file/line references.
```

## Example Minimal Practice Question Lab

This is an example shape only. Do not copy it verbatim if generating a real lab.

`config.json`:

```json
{
  "lab": "cka-005",
  "workerNodes": 2,
  "answers": "assets/exams/cka/005/answers.md",
  "questions": "assessment.json",
  "totalMarks": 100,
  "lowScore": 40,
  "mediumScore": 60,
  "highScore": 90
}
```

`assessment.json`:

```json
{
  "questions": [
    {
      "id": "1",
      "namespace": "cka-q01",
      "machineHostname": "ckad9999",
      "question": "In namespace `cka-q01`, the Service `payments-api` has no Endpoints because it selects the wrong Pods.\n\nFix the Service so it targets Pods with label `app=payments` and port `8080`.\n\nDo not recreate the Deployment.",
      "concepts": ["Services", "Endpoints", "selectors", "troubleshooting"],
      "verification": [
        {
          "id": "1",
          "description": "Service selector targets app=payments",
          "verificationScriptFile": "q1_s1_validate_selector.sh",
          "expectedOutput": "0",
          "weightage": 25
        },
        {
          "id": "2",
          "description": "Service exposes port 8080",
          "verificationScriptFile": "q1_s2_validate_port.sh",
          "expectedOutput": "0",
          "weightage": 25
        },
        {
          "id": "3",
          "description": "Service has ready Endpoints",
          "verificationScriptFile": "q1_s3_validate_endpoints.sh",
          "expectedOutput": "0",
          "weightage": 25
        },
        {
          "id": "4",
          "description": "Deployment was not recreated or renamed",
          "verificationScriptFile": "q1_s4_validate_deployment.sh",
          "expectedOutput": "0",
          "weightage": 25
        }
      ]
    }
  ]
}
```

`scripts/setup/q1_setup.sh`:

```bash
#!/bin/bash
set -euo pipefail

NS="cka-q01"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete service payments-api --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete deployment payments-api --ignore-not-found=true >/dev/null 2>&1 || true

kubectl -n "$NS" create deployment payments-api --image=nginx:1.25 --replicas=2
kubectl -n "$NS" label deployment payments-api app=payments --overwrite
kubectl -n "$NS" expose deployment payments-api --name=payments-api --port=80 --target-port=8080
kubectl -n "$NS" patch service payments-api -p '{"spec":{"selector":{"app":"wrong"}}}'

exit 0
```

`scripts/validation/q1_s1_validate_selector.sh`:

```bash
#!/bin/bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

NS="cka-q01"
SVC="payments-api"

SELECTOR="$(kubectl -n "$NS" get service "$SVC" -o jsonpath='{.spec.selector.app}')"
[ "$SELECTOR" = "payments" ] || fail "Expected selector app=payments, got ${SELECTOR:-empty}"

pass "Service selector is correct"
```

## Final Checklist Before Marking A Lab Ready

Use this checklist every time:

- The lab folder is under `facilitator/assets/exams/cka/NNN/`.
- No existing CKA folder was overwritten.
- `labs.json` contains exactly one matching `cka-NNN` entry.
- `config.json` `lab` matches `cka-NNN`.
- `config.json` `answers` path is correct.
- `assessment.json` is valid JSON.
- Every question ID is sequential.
- Every question uses `machineHostname: ckad9999`.
- Every namespaced question has a sensible namespace.
- Every question has useful `concepts`.
- Every question has 2 to 5 validation steps.
- Every validation script file exists.
- Total validation weightage equals exactly `100`.
- Setup scripts are idempotent.
- Validation scripts return `0` only when the required end state is correct.
- Scripts pass `bash -n`.
- No generated `assets.tar.gz` is committed.
- The lab does not require unsupported kubeadm behavior unless clearly
  simulated.
- The lab appears in the UI after facilitator rebuild/restart.
- Completing the lab creates an attempt history record.
