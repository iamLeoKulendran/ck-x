# CK-X → CKS Simulator Migration Plan (Killer.sh-Style)

Status: planning document. No implementation is included in this file.

Date: 2026-06-11
Owner: Leo (CKA completed; preparing for CKS)
Related docs: `docs/kubeadm-backend-upgrade-plan.md`, `docs/cka-lab-generation-guide.md`

---

## 1. Goal

Upgrade CK-X from a CKA-tuned simulator into a Killer.sh-style **CKS** practice
simulator for private exam preparation:

- Exam-day feel: 2-hour timed sessions, ~16 questions, per-question
  percentage weights, multiple cluster contexts, SSH into nodes.
- Real (not simulated) security tasks wherever the local backend allows it.
- Honest, clearly labeled bridge/simulation tasks only where the laptop
  backend genuinely cannot provide the real thing.
- Post-exam review like Killer.sh: score breakdown per task plus a full
  solutions walkthrough, with the environment kept alive for replaying.

Legal scope note: "Killer.sh-style" means the **format and rigor** (timed UI,
weighted scoring, detailed solutions, hard scenario questions). No Killer.sh,
PSI, Linux Foundation, or real exam content is copied, scraped, or reproduced.
All questions are original.

## 2. What "Killer.sh-Style" Means Concretely

Target user experience, feature by feature:

| Killer.sh trait | CK-X today | Gap |
| --- | --- | --- |
| Timed 2h session, question panel, flagging | Yes (Exam Mode UI) | None |
| Per-question weight shown as a percentage | Weightage exists in `assessment.json`, drives scoring | Show the % in the question panel UI |
| Each question states its cluster/context (`kubectl config use-context ...`) | Single k3d cluster, single context | Multi-cluster/context support (Section 6.4) |
| SSH into controlplane/worker nodes | Yes (`ssh controlplane`, `ssh node01`) — k3d node containers | Make node internals CKS-capable (tooling, kubeadm paths) |
| Score page with per-task pass/fail checks | Yes (validation steps + Weak Areas history) | None — already stronger than baseline |
| Detailed solutions with explanations after scoring | `answers.md` exists per lab but is not surfaced in the UI | Add post-evaluation "Solutions" view (Section 6.5) |
| Environment stays usable after scoring for replay | Evaluation does not tear down the cluster | Verify + document; add "re-run setup for question N" helper |
| Harder-than-real-exam difficulty | CLAUDE.md already mandates Medium-Hard | Carry the same bar into CKS content rules |
| Two scoring sessions per purchase | N/A locally | Free replays — already better locally |

Conclusion: the **platform** is ~80% there. The migration is mostly
(a) backend capability for security topics, (b) CKS content pipeline,
(c) two UI affordances (weights display, solutions view), (d) multi-context.

## 3. CKS Curriculum Map vs. Current Backend

Current CKS domains and weights (re-verify against the official curriculum
when generating each mock):

| # | Domain | Weight |
| --- | --- | --- |
| 1 | Cluster Setup | 15% |
| 2 | Cluster Hardening | 15% |
| 3 | System Hardening | 10% |
| 4 | Minimize Microservice Vulnerabilities | 20% |
| 5 | Supply Chain Security | 20% |
| 6 | Monitoring, Logging and Runtime Security | 20% |

Feasibility on the current k3d backend, topic by topic:

### Works today on k3d (no backend change needed) — roughly 60–70% of the exam

- NetworkPolicies, including default-deny and namespace/pod selector policies
  (K3s ships a network policy controller that enforces them).
- RBAC hardening: roles, bindings, least privilege, `kubectl auth can-i`.
- ServiceAccount hardening: `automountServiceAccountToken: false`, dedicated
  SAs, token audience/projection.
- Pod Security Admission / Pod Security Standards (namespace labels:
  baseline/restricted, audit/warn/enforce).
- SecurityContexts: runAsNonRoot, readOnlyRootFilesystem, drop capabilities,
  allowPrivilegeEscalation, privileged-pod hunting.
- Seccomp: `RuntimeDefault` and `Localhost` profiles (kernel has
  `CONFIG_SECCOMP=y` — verified on this machine).
- Secrets: creation, mounting, base64 inspection, encryption-at-rest *concept*
  (real `EncryptionConfiguration` needs API-server flag access → kubeadm phase).
- ValidatingAdmissionPolicy (in-tree, CEL-based) — no extra install needed.
- OPA Gatekeeper / Kyverno: install via manifests/Helm in setup scripts,
  write/repair constraints or policies.
- Ingress with TLS (install ingress-nginx in setup; K3s Traefik is disabled in
  the current cluster bootstrap or can be).
- Supply chain static work: image digest pinning, registry allowlisting via
  policy engine, Dockerfile hardening review, `trivy` image scanning,
  `kubesec`/`kube-score` manifest scanning, SBOM generation with `bom`/`syft`,
  signature verification with `cosign` (tools must be added to the jumphost —
  Section 6.2).
- Audit-log *analysis*: setup script plants a pre-generated audit log file;
  candidate greps/answers from it.
- Immutable containers, runtime behavior analysis from provided logs.

### Possible on this laptop with kernel/runtime enablement (Phase 2)

Verified facts from this machine (WSL2 kernel `6.6.87.2-microsoft-standard`):

| Capability | Kernel status (verified) | What unlocks it |
| --- | --- | --- |
| AppArmor | `CONFIG_SECURITY_APPARMOR=y` compiled in, but **not active** (`/sys/module/apparmor/parameters/enabled` = N) | Add `kernelCommandLine = lsm=lockdown,yama,apparmor,bpf security=apparmor` to `%USERPROFILE%\.wslconfig`, `wsl --shutdown`, restart Docker Desktop. Then load profiles inside node containers with `apparmor_parser`. |
| Falco (runtime detection) | BTF present (`/sys/kernel/btf/vmlinux`), `CONFIG_BPF_SYSCALL=y` | Falco **modern eBPF** driver as a DaemonSet or inside node containers. No kernel module build needed. |
| gVisor / RuntimeClass | Independent of kernel modules | Install `runsc` + `containerd-shim-runsc-v1` in the node image, register the containerd runtime handler, create RuntimeClass `gvisor`. Use the `systrap` platform (no KVM in WSL2). |
| Kernel audit (`auditd`) | `CONFIG_AUDIT=y` | Host-level auditd labs are unreliable in nested containers (one audit daemon per kernel) → keep as bridge labs. Kubernetes **API audit logging** is userspace and unaffected (needs kubeadm phase for live config). |

If the `.wslconfig` AppArmor change fails for any reason, AppArmor questions
fall back to bridge format (write the profile + the `apparmor_parser` command
to a file; validation checks file contents).

### Requires the kubeadm backend (Phase 3) — real versions

- API server hardening flags: enable audit logging (`--audit-policy-file`,
  `--audit-log-path`), admission plugins, anonymous auth off, insecure flags.
- `EncryptionConfiguration` for secrets at rest + verifying etcd contents
  with `etcdctl`.
- kubelet hardening (`readOnlyPort`, `authentication.anonymous.enabled`,
  authorization mode).
- kube-bench CIS runs with real findings to remediate under
  `/etc/kubernetes/manifests` and kubelet config.
- Certificate inspection, binary verification against checksums.
- Until Phase 3 lands, these run as clearly-labeled simulation/bridge tasks
  (the repo already has rules and precedent for this).

## 4. The Real Limitations and How Each Is Overcome

| # | Limitation | Overcome by | Phase |
| --- | --- | --- | --- |
| L1 | k3d/K3s is not kubeadm: no `/etc/kubernetes/manifests`, no live API-server/kubelet flag editing | Optional `CLUSTER_DRIVER=kubeadm` backend (plan already exists in `docs/kubeadm-backend-upgrade-plan.md`); two nodes `controlplane` + `node01` | 3 |
| L2 | AppArmor inactive in stock WSL2 boot | `.wslconfig` `kernelCommandLine` enablement (module is compiled in — verified); fallback bridge labs | 2 |
| L3 | No runtime threat detection tooling | Falco with modern eBPF (BTF verified present); ship as DaemonSet manifest in lab setup | 2 |
| L4 | No sandboxed runtime | gVisor `runsc` (systrap) baked into node image + RuntimeClass | 2–3 |
| L5 | Jumphost lacks CKS tooling | Jumphost image v2: trivy, kube-bench, kubesec, cosign, syft/bom, etcdctl, jq, yq, openssl, apparmor-utils, curl, git (Section 6.2) | 1 |
| L6 | Single cluster/context vs. exam's per-question contexts | k3d supports multiple named clusters; merge kubeconfigs; add `context` field per question (Section 6.4). Keep default at 1 cluster for RAM; use 2 only in full mocks | 4 |
| L7 | No in-UI solutions after scoring | Facilitator endpoint serving rendered `answers.md` post-evaluation + UI "Solutions" tab (Section 6.5) | 4 |
| L8 | Content pipeline is CKA-only (skill, CLAUDE.md, generation guide) | Create `cks-exam-generator-2026` skill + `docs/cks-lab-generation-guide.md` + CLAUDE.md CKS rules (Section 7) | 1 |
| L9 | Laptop RAM/CPU budget | Keep 1 server + 1–2 agents; pre-pull security tool images in node image build; Falco/Gatekeeper only installed by labs that need them | all |
| L10 | Registry/network-restricted tasks (private registry, image allowlists) | Run a local `registry:2` container inside the cluster host; reference as `registry.local:5000` | 2 |

## 5. Current State Inventory (what we keep unchanged)

- Compose topology: nginx (localhost-only) → webapp / facilitator /
  remote-desktop / remote-terminal; jumphost `ckad9999`; `k8s-api-server`
  DinD host; Redis; attempt-history volume. **No new public ports.**
- Exam lifecycle contracts: `labs.json` registry, `config.json` /
  `assessment.json` / `answers.md` per lab, `scripts/setup/qX_setup.sh`,
  `scripts/validation/qX_sY_*.sh`, exit-code scoring, weightage totals 100.
- Previous Attempts / Weak Areas history (works for CKS automatically since
  weak-concept tracking is driven by lab metadata).
- The CKS category already exists: `labs.json` has `cks-001` and
  `facilitator/assets/exams/cks/001/` is a working 20-question lab. It becomes
  the smoke-test lab for every phase.

Housekeeping to do first (Phase 0): fix the `cka-001` registry entry only if
`facilitator/assets/exams/cka/001/` is actually missing locally. Verified
2026-06-11: the folder was deleted in commit `12e14c8` and does not exist, so
the stale `cka-001` entry is removed from `labs.json` in Phase 0 (backup kept
at `labs.json.phase0.bak`).

## 6. Architecture Changes

### 6.1 Cluster driver switch (unchanged from kubeadm plan)

```text
CLUSTER_DRIVER=k3d      # default, stays stable
CLUSTER_DRIVER=kubeadm  # opt-in once Phase 3 lands
```

`kind-cluster/scripts/env-setup` dispatches on the driver. Facilitator and UI
contracts do not change.

### 6.2 Jumphost image v2 (CKS toolbox)

Add to `jumphost/Dockerfile` (pinned versions, amd64+arm64 where available):

```text
trivy        # image and filesystem scanning
kube-bench   # CIS benchmark (run via job manifest or ssh to nodes)
kubesec      # manifest static analysis
cosign       # image signature verification
bom / syft   # SBOM generation and inspection
etcdctl      # secrets-at-rest verification (kubeadm phase)
openssl, jq, yq, curl, git, apparmor-utils
falco rules files (reference copies for authoring)
```

Budget note: this grows the jumphost image; keep tools as static binaries
(most are single Go binaries) and avoid daemon installs on the jumphost.

### 6.3 Node image additions (k3d custom image / kubeadm node image)

- gVisor `runsc` + shim, containerd runtime handler `runsc`.
- AppArmor userspace (`apparmor_parser`) for loading profiles.
- Pre-pulled images used by CKS labs (Falco, Gatekeeper/Kyverno,
  ingress-nginx, registry:2, sample vulnerable images) to keep exam start fast.

### 6.4 Multi-context support (Killer.sh feel)

- `env-setup` optionally creates a second small k3d cluster (or in kubeadm
  mode, contexts pointing at the same cluster with different users for
  RBAC questions).
- Kubeconfigs merged into `/home/candidate/.kube/config` with named contexts.
- `assessment.json` question schema gains an optional informational field
  rendered at the top of each question:

```json
"contextHint": "kubectl config use-context cks-cluster-b"
```

- Default mocks stay single-cluster to respect the RAM budget; flagship full
  mocks may use two.

### 6.5 Killer.sh-style review UX

- Show each question's weight (e.g. `Weight: 8%`) in the question panel —
  data already exists in `assessment.json`.
- After evaluation, add a **Solutions** view: facilitator serves the lab's
  `answers.md` (rendered markdown) only once the exam status is `EVALUATED`,
  alongside the per-step pass/fail list the UI already has.
- Keep the cluster alive after scoring (verify current behavior; document
  "review mode") so failed tasks can be replayed immediately.
- Optional later: per-question "reset this question" helper that re-runs
  `qX_setup.sh` for one question.

### 6.6 Capability flags in the registry

Add an optional `requiredCapabilities` array to `labs.json` entries, e.g.
`["apparmor", "falco-ebpf", "gvisor", "kubeadm"]`. The facilitator (or simply
the lab description, as a first step) surfaces which host enablement a lab
needs, so a lab never fails mysteriously because `.wslconfig` wasn't set.

## 7. Content Pipeline (CKS generation rules)

Create alongside, not replacing, the CKA pipeline:

1. **Skill**: `.claude/skills/cks-exam-generator-2026/` — clone the structure
   of `cka-exam-generator-2026`, swap in:
   - CKS domains/weights from Section 3.
   - Full mock format: **16 questions / 120 minutes** by default
     (allowed range 15–18), total weightage exactly 100.
   - Difficulty default: Hard (Killer.sh bar), Medium only when requested.
   - Backend capability matrix from Section 3 so the generator never emits a
     real-AppArmor question for a backend phase that can't run it.
   - Security-validation rule (already in repo rules): RBAC/policy checks must
     verify both **allowed and denied** behavior; every validation checks a
     positive final state.
2. **Guide**: `docs/cks-lab-generation-guide.md` — CKS counterpart of the CKA
   guide, including the bridge-task wording rules and the per-phase
   "real vs. simulation" topic table.
3. **CLAUDE.md**: add a CKS section (skill mandate, lab path
   `facilitator/assets/exams/cks/NNN/`, question count rules, capability
   gating) while keeping all existing platform rules (machineHostname
   `ckad9999`, idempotent setup, 2–5 validations per question, etc.).
4. **Question bank strategy** (Killer.sh-grade scenarios, all original):
   - Broken-state bias: "this policy/profile/binding exists but is wrong —
     find and fix it" over "create X from scratch".
   - Per-domain practice sets (`cks/00X`) + flagship full mocks.
   - Target inventory: 6 domain practice labs (one per domain) + 2 full
     16-question mocks, then grow from Weak Areas history.

## 8. Phased Migration Plan

### Phase 0 — Housekeeping (half a day)

- Resolve the `cka/001` vs. `labs.json` registry mismatch only if the folder
  is truly missing locally (verified missing on 2026-06-11 → deregister);
  commit a clean baseline.
- Back up `labs.json` and the attempt-history volume.
- Smoke-test existing `cks-001` end to end on the current stack.

Gate: clean `git status`, `cks-001` starts, scores, and records history.

### Phase 1 — CKS content pipeline on the current k3d backend (1–2 days)

- Jumphost image v2 with the CKS toolbox (Section 6.2).
- Create the `cks-exam-generator-2026` skill, the CKS generation guide, and
  the CLAUDE.md CKS rules.
- Generate `cks/002`: first Killer.sh-grade domain practice lab using only
  "works today" topics (NetworkPolicy, RBAC, PSA, SecurityContext, seccomp
  RuntimeDefault, trivy/kubesec/cosign tasks, ValidatingAdmissionPolicy).
- Run the full repo validation checklist (JSON valid, `bash -n`, chmod +x,
  weightage 100, false-positive audit, validation-report.md).

Gate: `cks/002` passes a full simulated attempt; all tools run on jumphost.

### Phase 2 — Host capability enablement (1–2 days, mostly verification)

- AppArmor: `.wslconfig` kernel command line change; verify
  `cat /sys/module/apparmor/parameters/enabled` → `Y`; load a test profile in
  a k3d node; run a pod with an AppArmor annotation/field.
- Falco: deploy modern-eBPF Falco DaemonSet in k3d; trigger and observe a
  rule; build one detection lab.
- gVisor: custom k3d node image with runsc; RuntimeClass lab
  (`dmesg` inside pod shows gVisor kernel).
- Local registry container for supply-chain labs.
- Document each enablement + fallback in README ("CKS host setup").

Gate: each capability has a one-question proof lab that passes validation;
fallback bridge wording documented for any capability that fails on WSL2.

### Phase 3 — kubeadm driver (the big one; follows `docs/kubeadm-backend-upgrade-plan.md`)

- Implement `CLUSTER_DRIVER=kubeadm` POC: `controlplane` + `node01`,
  containerd, CNI, ssh access, shared kubeconfig — per the existing plan's
  phases, with one addition: bake CKS tooling (Section 6.3) into the node
  image from the start.
- Unlocks real labs: API-server audit logging, EncryptionConfiguration +
  etcdctl verification, kubelet hardening, kube-bench remediation,
  admission plugin flags, cert inspection, binary verification.
- k3d remains the default driver; CKS labs that need kubeadm declare
  `requiredCapabilities: ["kubeadm"]`.

Gate: the existing kubeadm plan's Phase 6 quality gates, plus one real
audit-logging lab and one EncryptionConfiguration lab passing end to end.

### Phase 4 — Killer.sh UX parity (1–2 days)

- Question-panel weight percentage display.
- Post-evaluation Solutions view (rendered `answers.md`).
- Verified keep-alive review mode after scoring.
- Optional: multi-context support + `contextHint` rendering.

Gate: full attempt on `cks/002` shows weights during the exam and full
solutions + per-step results after scoring; cluster still usable.

### Phase 5 — Flagship CKS mocks (ongoing)

- `cks/010` and `cks/011`: two full 16-question, 120-minute mocks with
  domain coverage matching Section 3 weights, mixed across all unlocked
  capabilities (mock 1: k3d-only topics; mock 2: requires Phase 2/3).
- Per-domain drill labs for the remaining domains.
- Use Weak Areas history after each attempt to generate targeted drills.

Gate: two timed self-attempts each ≥ the real exam pass mark (67%) under
exam conditions before booking the real CKS.

### Phase 6 — Quality gates (continuous, per lab)

- All JSON valid; `bash -n` clean; scripts executable.
- Every `verificationScriptFile` exists; weightage totals exactly 100;
  2–5 validations per question (3–5 for hard troubleshooting).
- False-positive audit: no validation passes on the freshly-broken setup
  state; positive final-state checks only; RBAC/policy checks assert both
  allow and deny.
- End-to-end: start → setup → solve from `answers.md` → evaluate → 100%.
- `docker compose down` / `up -d` preserves history; no new public ports.

## 9. Effort and Order-of-Value Summary

| Phase | Effort | Value unlocked |
| --- | --- | --- |
| 0 | hours | Clean baseline |
| 1 | 1–2 days | ~60–70% of CKS curriculum practicable immediately |
| 2 | 1–2 days | AppArmor, Falco, gVisor — the "CKS-only" runtime topics |
| 3 | the largest chunk | The last ~20%: control-plane hardening for real |
| 4 | 1–2 days | Killer.sh exam-day feel and review loop |
| 5 | ongoing | Mock exams + weak-area drills until exam-ready |

Recommended order is exactly 0 → 1 → 2 → 4 → 5(mock 1) → 3 → 5(mock 2):
Phase 4 is cheap and improves every practice session, so it should not wait
for the kubeadm driver. You can be doing productive CKS practice at the end
of Phase 1.

## 10. Risks and Mitigations

- **WSL2 kernel quirks** (AppArmor cmdline ignored, Falco eBPF probe issues):
  every Phase 2 capability has a documented bridge-lab fallback; nothing
  blocks the content pipeline.
- **RAM pressure** (Falco + Gatekeeper + ingress + 2 clusters): labs install
  only what they use; flagship mocks document a 12 GB+ WSL memory
  recommendation; default stays 1 server + 1–2 workers.
- **kubeadm driver complexity**: already isolated behind `CLUSTER_DRIVER`
  with k3d as the untouched default; CKS practice does not depend on it
  until mock 2.
- **Content drift vs. official curriculum**: the generator skill records the
  curriculum version used; re-verify domain weights before generating each
  full mock.
- **Scope creep toward "exact Killer.sh clone"**: parity targets are format
  and rigor only (Section 2 table); anything beyond that list is out of
  scope for this migration.
