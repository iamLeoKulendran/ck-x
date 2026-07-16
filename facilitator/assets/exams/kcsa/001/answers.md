# KCSA Practice Exam 1 — Answers & Explanations

Original CK-X practice content. Not affiliated with CNCF or the Linux Foundation.

## Question 1 — The 4 Cs
**Answer: B.** Cloud → Cluster → Container → Code, outermost to innermost. Weaknesses in an outer layer undermine everything inside it.

## Question 2 — etcd access
**Answer: B.** etcd holds every API object including Secrets, which are only base64-encoded by default. Without encryption at rest, etcd read access means reading all Secrets.

## Question 3 — Kubelet hardening
**Answers: A, B, D.** Disable anonymous auth, use Webhook authorization, require client certificates. The read-only port (10255) is unauthenticated and should be disabled entirely.

## Question 4 — Pod Security Standards
**Answer: B.** baseline blocks privileged containers, host namespaces, and hostPath while permitting typical workloads. restricted adds non-root, seccomp, and capability drops.

## Question 5 — RBAC scope
**Answer: B.** Role + RoleBinding are namespaced: get/list on Secrets applies only inside team-a, and create was never granted.

## Question 6 — Accountability
**Answer: B.** API server audit logging records requests per the audit policy — the only listed control that produces an actor-attributable history.

## Question 7 — Trust boundary collapse
**Answer: B.** Privileged + hostPID removes the container/host boundary; the workload can reach host processes and devices — node takeover.

## Question 8 — Persistence
**Answer: A.** A high-privilege ServiceAccount used by a controller-managed workload preserves attacker access across Pod restarts and node reboots.

## Question 9 — Image signing
**Answer: B.** Signature verification proves provenance and integrity (untampered, from a trusted publisher). Vulnerability discovery requires scanning, not signing.

## Question 10 — CIS Benchmark
**Answer: A.** kube-bench executes the CIS Kubernetes Benchmark checks and reports per-recommendation pass/fail.
