# cks-004 Validation Report

**Lab:** cks-004 — Mock Exam - CKS - 3
**Date:** 2026-06-12
**Backend:** k3d / k3s v1.31.5+k3s1 inside DinD (`k8s-api-server`), registry-backed
**Result:** PASS — fresh state 0/49, answered state 49/49

## Exam shape

- 16 questions, 120 minutes, Hard, `machineHostname: ckad9999`
- Total weightage: 100 (verified)
- Validation scripts: 49 (2–4 per question)

## Domain coverage (exact CKS weights)

| Domain | Target | Lab |
|---|---|---|
| Cluster Setup | 15 | 15 (q1, q2) |
| Cluster Hardening | 15 | 15 (q3, q4, q5) |
| System Hardening | 10 | 10 (q6, q7) |
| Minimize Microservice Vulnerabilities | 20 | 20 (q8, q9, q10) |
| Supply Chain Security | 20 | 20 (q11, q12, q13) |
| Monitoring, Logging and Runtime Security | 20 | 20 (q14, q15, q16) |

## Tier classification

All 16 questions are Tier 1 (k3d-safe real tasks). No AppArmor, Falco, gVisor, or
kubeadm tasks. No bridge/simulation tasks. q14 is a planted-artifact analysis task
(audit log), which is a Tier-1 file-analysis pattern, not a Tier-2/3 bridge.

## Registry usage (internal registry only — no public pulls)

| Question | Registry image | Use |
|---|---|---|
| q1 storefront | `registry.localhost:5000/ckx/nginx:v1.25` | served workload |
| q1 clients | `registry.localhost:5000/ckx/alpine:3.20` | test clients |
| q2 portal | `registry.localhost:5000/ckx/nginx:v1.25` | TLS Ingress backend |
| q5 compliant pod | `registry.localhost:5000/ckx/nginx:v1.25` | admitted by VAP |
| q6 edge-cache | `registry.localhost:5000/ckx/alpine:3.20` | hardened workload |
| q7 metrics-shipper | `registry.localhost:5000/ckx/alpine:3.20` | seccomp workload |
| q8 orders-ui | `registry.localhost:5000/ckx/alpine:3.20` | restricted PSA |
| q9 billing | `registry.localhost:5000/ckx/nginx:v1.25` | secret hygiene |
| q10 processor/ledger | alpine + nginx | egress source/target |
| q11 web-frontend | `registry.localhost:5000/ckx/nginx@sha256:...` | **digest pinning** |
| q12 scanner-api | `registry.localhost:5000/ckx/alpine:3.20` | hardened deploy |
| q13 trusted-release | `registry.localhost:5000/ckx/nginx:v1.25` + `ckx/alpine:3.20` SBOM | SBOM/cosign |
| q15 ingest-api | `registry.localhost:5000/ckx/alpine:3.20` | incident response |
| q16 log-rotator | `registry.localhost:5000/ckx/alpine:3.20` | immutable rootfs |

No image is pulled from Docker Hub or any external registry at exam runtime.
q12's planted `workload.yaml` references `nginx:1.25` only as scan input (never deployed).

## Runtime validation (live cluster)

1. All 16 setup scripts ran clean.
2. Fresh broken state: **0 / 49** validations pass (no false positives).
3. answers.md solutions applied.
4. Answered state: **49 / 49** validations pass.
5. The 3 structural/jsonpath validations rewritten during testing (q1_s4, q9_s3,
   q10_s3) were re-confirmed to fail on the fresh broken state.

## Backend note — NetworkPolicy enforcement

The k3s embedded network-policy controller runs and programs `KUBE-NWPLCY` iptables
chains, but **namespace-isolation enforcement does not take effect** in this nested
DinD cluster (a pure default-deny egress still permits traffic). Connectivity-based
*denial* therefore cannot be observed here.

To keep grading deterministic and environment-independent:
- **Allowed-path** NetworkPolicy checks (q1_s3, q10_s2) use live connectivity (traffic
  flows and the registry-backed workload serves), guarded by policy existence.
- **Denied-path** checks (q1_s4, q10_s3) verify policy *structure/semantics* (default-deny
  present + allow rules scoped only to the intended selector), which guarantees the
  denied source/destination is refused by NetworkPolicy rules regardless of CNI
  enforcement. q15_s3 (default-deny-all) is likewise structural.

Admission-control enforcement (ValidatingAdmissionPolicy q5, Pod Security Admission q8)
**does** work on this backend and is validated by real rejection of violating pods.

## Tooling confirmed working offline

- `trivy config` (built-in misconfig policies, no DB download) — q12
- `syft docker:registry:5000/ckx/alpine:3.20 -o spdx-json` — q13
- `cosign sign-blob` / `verify-blob` with `--use-signing-config=false --tlog-upload=false
  --new-bundle-format=false` (sign) and `--insecure-ignore-tlog` (verify) — q13
- registry digest via `curl -I` with OCI manifest Accept header — q11

## Assumptions

- `ckx/alpine:3.20` and `ckx/nginx:v1.25` are present in the internal registry
  (seeded by `seed-registry-images`, Phase 2D).
- Hardened workloads use the alpine `sleep infinity` pattern because stock nginx cannot
  run under `drop: ["ALL"]` (loses CAP_NET_BIND_SERVICE for port 80) or
  `readOnlyRootFilesystem` (cannot write its temp dirs).
