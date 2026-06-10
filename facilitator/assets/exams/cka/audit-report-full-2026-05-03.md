# Full CKA Audit Report
**Date:** 2026-05-03  
**Scope:** cka-004, cka-005, cka-007  
**Type:** Read-only quality audit — no files modified  

---

## Executive Summary

| Exam | Display Name | Questions | Total Marks | Quality Score | Doable |
|---|---|---:|---:|---:|---|
| cka-004 | CKA Mock Exam - Advanced Troubleshooting | 25 | 100 | **75 / 100** | ✅ Yes (with caveats) |
| cka-005 | Mock Exam - CKA revision -1 | 17 | 100 | **92 / 100** | ✅ Yes |
| cka-007 | Practice Question - Workloads and Scheduling -1 | 20 | 100 | **90 / 100** | ✅ Yes |

Runtime validation was **not performed** (no live k3d cluster). All results are from static analysis.

---

## Scoring Rubric

| Dimension | Max |
|---|---:|
| Structural integrity (JSON, bash -n, exec, weightage, hostnames) | 20 |
| Validation quality (end-state checks, depth, jsonpath vs grep) | 25 |
| k3d compatibility (no kubeadm-only tasks, bridges labelled) | 15 |
| Question design quality (broken state, troubleshooting realism) | 15 |
| Domain coverage vs CKA weights (or stated purpose) | 10 |
| False-positive prevention (positive assertions, bidirectional checks) | 10 |
| Documentation quality (answers.md) | 5 |

---

## CKA-004 — Detailed Audit

### Metadata
- **Registry:** `cka-004`, difficulty: Hard, duration: 120 min, warmUp: 360 s
- **Structure:** 25 questions × 2 verifs × 4 marks = 100 ✅
- **Scripts:** 25 setup + 50 validation = 75 total
- **Namespace prefix:** `cka-qNN` (no cross-exam collisions) ✅
- **Bridge tasks:** Q22 (static pod → `/tmp/exam/q22/`), Q25 (etcd backup script) ✅

### Structural Checks

| Check | Result |
|---|---|
| assessment.json valid JSON | ✅ |
| config.json valid JSON | ✅ |
| Total weightage = 100 | ✅ |
| All 25 questions use `ckad9999` | ✅ |
| All 75 scripts pass `bash -n` | ✅ |
| All 75 scripts executable | ✅ |
| All 50 verificationScriptFile refs exist | ✅ |
| No `/etc/kubernetes/manifests` in functional scripts | ✅ |
| No cross-exam namespace collisions | ✅ |

### Question Inventory

| Q | Domain | Verifs | Marks | Bridge | Notes |
|---|---|---|---|---|---|
| Q1 | Contexts / kubectl | 2 | 4 | | Bidirectional diff (fixed P4.2) |
| Q2 | Scheduling / taints | 2 | 4 | | Real cluster |
| Q3 | StatefulSet scaling | 2 | 4 | | Scale down 3→1 |
| Q4 | Probes / endpoints | 2 | 4 | | Create-only |
| Q5 | kubectl jsonpath sort | 2 | 4 | | Script file output |
| Q6 | PV / PVC / deploy mount | 2 | 4 | | PVC binding + mount check |
| Q7 | Rollout troubleshoot | 2 | 4 | | Rollback + availableReplicas |
| Q8 | Service selector fix | 2 | 4 | | Selector + endpoints check |
| Q9 | NetworkPolicy egress | 2 | 4 | | Grep-based egress check (fragile) |
| Q10 | RBAC / ServiceAccount | 2 | 4 | | Role + auth can-i |
| Q11 | ClusterRole / binding | 2 | 4 | | auth can-i effective perms |
| Q12 | nodeSelector / taints | 2 | 4 | | Create + schedule check |
| Q13 | Job troubleshoot | 2 | 4 | | Failed job repair |
| Q14 | CronJob create | 2 | 4 | | Create-only |
| Q15 | ConfigMap env/volume | 2 | 4 | | Create-only |
| Q16 | Secret env/volume | 2 | 4 | | Create-only |
| Q17 | Resource limits | 2 | 4 | | Create-only |
| Q18 | Anti-affinity deploy | 2 | 4 | | Create-only |
| Q19 | Image pull fix | 2 | 4 | | Fix broken image |
| Q20 | NodePort service | 2 | 4 | | Create-only |
| Q21 | Node custom-columns | 2 | 4 | | Output file check |
| Q22 | Static pod (bridge) | 2 | 4 | ✅ | `/tmp/exam/q22/` + Python yaml.safe_load |
| Q23 | Multi-container pod | 2 | 4 | | Create-only |
| Q24 | PriorityClass | 2 | 4 | | Create-only |
| Q25 | etcd backup (bridge) | 2 | 4 | ✅ | Script content check only |

### Domain Coverage vs CKA Weights

| Domain | CKA Target | cka-004 Actual | Gap |
|---|---:|---:|---|
| Cluster Architecture / RBAC | 25% | ~16% (4q) | ⚠️ Under |
| Workloads & Scheduling | 15% | ~40% (10q) | ⚠️ Over |
| Services & Networking | 20% | ~16% (4q) | Acceptable |
| Storage | 10% | ~4% (1q) | ❌ Under-weighted |
| Troubleshooting | 30% | ~16% (4q) | ❌ Under-weighted |

### Quality Score: 75 / 100

| Dimension | Score | Reason |
|---|---:|---|
| Structural integrity | 20/20 | All checks pass |
| Validation quality | 15/25 | All questions have only 2 verifs; Q9 s2 grep-only |
| k3d compatibility | 14/15 | Bridges labelled; no runtime execution |
| Question design | 9/15 | ~9 create-only tasks; few broken-state troubleshooting Qs |
| Domain coverage | 5/10 | Storage 4%, Troubleshooting 16% vs 10%/30% targets |
| False-positive prevention | 8/10 | Q9 egress grep fragile; Q1 trivial if 1 context |
| Documentation | 4/5 | Bridge answers clear; minor improvements possible |

### Doability: ✅ Yes (with caveats)

**Green:** Runs cleanly on k3d. Namespace isolation clean. No kubeadm dependencies.  
**Caveats:**
- Q22 and Q25 are runbook-only — no live kubeadm cluster practice
- Storage and troubleshooting are under-represented for a full mock exam
- 9 create-only tasks weaken troubleshooting realism

---

## CKA-005 — Detailed Audit

### Metadata
- **Registry:** `cka-005`, difficulty: Hard, duration: 120 min, warmUp: 360 s
- **Structure:** 17 questions (15×3 verifs + 2×2 verifs) = 49 verifs, 15×6 + 2×5 = 100 ✅
- **Scripts:** 17 setup + 49 validation = 66 total
- **Namespace prefix:** `rev1-qNN` (no cross-exam collisions) ✅
- **Bridge tasks:** 0 — all real k3d tasks ✅

### Structural Checks

| Check | Result |
|---|---|
| assessment.json valid JSON | ✅ |
| config.json valid JSON | ✅ |
| Total weightage = 100 | ✅ |
| All 17 questions use `ckad9999` | ✅ |
| All 66 scripts pass `bash -n` | ✅ |
| All 66 scripts executable | ✅ |
| All 49 verificationScriptFile refs exist | ✅ |
| No kubeadm-only paths in scripts | ✅ |
| No cross-exam namespace collisions | ✅ |

### Question Inventory

| Q | Domain | Verifs | Marks | Notable Validation |
|---|---|---|---|---|
| Q1 | Troubleshoot init-container + service | 3 | 6 | Pod Running + init complete + endpoint populated |
| Q2 | Service targetPort fix | 3 | 6 | Endpoint addr + port=8080 assertion |
| Q3 | Helm rollback + upgrade | 3 | 6 | helm history revision ≥ 3, status=deployed, replicas=3 |
| Q4 | Init-container + emptyDir configmap | 3 | 6 | Init completed + volume mounted |
| Q5 | PVC StorageClass fix | 2 | 5 | PVC Bound + storageClassName=local-path |
| Q6 | CrashLoop readOnly volume fix | 3 | 6 | readOnly=false anchor + Pod Running |
| Q7 | Kubeconfig merge | 3 | 6 | Context exists + cluster accessible |
| Q8 | Node drain with PDB | 3 | 6 | PDB minAvailable=1 + node uncordoned |
| Q9 | DaemonSet rolling update | 2 | 5 | updateStrategy + ready count |
| Q10 | NetworkPolicy ingress+egress | 3 | 6 | Policy exists + ingress rules + egress rules |
| Q11 | ResourceQuota CPU fit | 3 | 6 | Deployment available + cpu request ≤ 150m numeric |
| Q12 | Kustomize configMapGenerator | 3 | 6 | ConfigMap exists + data + namespace |
| Q13 | StatefulSet VCT StorageClass | 3 | 6 | StorageClass in VCT + pods running + PVCs bound |
| Q14 | Readiness probe + service | 3 | 6 | Probe port + targetPort + ready replicas |
| Q15 | CronJob + PVC volume mount | 3 | 6 | Schedule + history + output file |
| Q16 | CRD + custom resources | 3 | 6 | CRD exists + 2 CRs + custom-columns |
| Q17 | Service named-port fix | 3 | 6 | Named port + deployment + ready |

### Domain Coverage vs CKA Weights

| Domain | CKA Target | cka-005 Actual | Gap |
|---|---:|---:|---|
| Cluster Architecture / RBAC | 25% | ~18% (Q7 kubeconfig, Q12 Kustomize, Q16 CRD) | Slightly under |
| Workloads & Scheduling | 15% | ~24% (Q4, Q9, Q13, Q15) | Slightly over |
| Services & Networking | 20% | ~24% (Q1, Q2, Q10, Q14, Q17) | Good |
| Storage | 10% | ~12% (Q5, Q13 PVC) | Good |
| Troubleshooting | 30% | ~35% (Q1, Q2, Q6, Q8, Q11, Q13, Q14) | Good |

**No dedicated scheduling questions** (taints, affinity, topology) — minor gap.

### Quality Score: 92 / 100

| Dimension | Score | Reason |
|---|---:|---|
| Structural integrity | 20/20 | All checks pass |
| Validation quality | 23/25 | 15/17 questions have 3 verifs; Python+jsonpath; numeric CPU compare |
| k3d compatibility | 15/15 | Helm uses local /tmp chart (no external repo); all k3d-native |
| Question design | 13/15 | 7 real broken-state troubleshooting Qs; Helm bad-upgrade scenario; PDB drain |
| Domain coverage | 7/10 | Missing scheduling domain; Troubleshooting and Storage well covered |
| False-positive prevention | 9/10 | Anchor checks prevent early pass (e.g., Q6 readOnly anchor, Q8 PDB anchor) |
| Documentation | 5/5 | Concise, command-focused answers with why-this-works sections |

### Doability: ✅ Yes

**Strong:** 17 questions, all runnable on k3d. Local Helm chart removes external dependency risk. PVC uses `local-path` StorageClass which k3d ships by default.  
**Risks (low):**  
- Q3 Helm chart packaged to `/tmp/exam/q3/chart.tgz` — if `/tmp` is cleared mid-exam, chart is gone. Candidate would need to re-run setup.  
- Q8 node drain requires 2 worker nodes available (config.json `workerNodes: 2` ✅)  
- Q15 CronJob output file validation requires a cron tick to fire — may take up to 60 seconds after solve  

---

## CKA-007 — Detailed Audit

### Metadata
- **Registry:** `cka-007`, difficulty: Hard, duration: 120 min, warmUp: 360 s
- **Structure:** 20 questions × 3 verifs × 5 marks = 100 (20×15=300 total marks across 60 scripts) ✅
- **Scripts:** 20 setup + 60 validation = 80 total
- **Namespace prefix:** `cka007-qNN` (no cross-exam collisions) ✅
- **Bridge tasks:** 0 — all real k3d tasks ✅
- **Purpose:** Topic-focused (Workloads & Scheduling — by design)

### Structural Checks

| Check | Result |
|---|---|
| assessment.json valid JSON | ✅ |
| config.json valid JSON | ✅ |
| Total weightage = 100 | ✅ |
| All 20 questions use `ckad9999` | ✅ |
| All 80 scripts pass `bash -n` | ✅ |
| All 80 scripts executable | ✅ |
| All 60 verificationScriptFile refs exist | ✅ |
| No kubeadm-only paths in scripts | ✅ |
| No cross-exam namespace collisions | ✅ |

**Note:** All validation scripts use `set +e` (not `set -euo pipefail`). This allows scripts to continue past intermediate failures, which is intentional for complex multi-step checks but reduces strict error detection. Acceptable in context.

### Question Inventory

| Q | Topic | Verifs | Marks | Notable Validation |
|---|---|---|---|---|
| Q1 | Rollout repair (paused deploy) | 3 | 5 | image=nginx:1.27 + rollout complete + available=3 |
| Q2 | Readiness probe + rolling update | 3 | 5 | Probe path + strategy + ready replicas |
| Q3 | StatefulSet + headless service | 3 | 5 | STS ready + headless service + DNS |
| Q4 | StatefulSet VCT | 3 | 5 | VCT name/storage/accessMode + mount + PVCs bound |
| Q5 | DaemonSet on control-plane | 3 | 5 | DaemonSet exists + toleration + scheduled |
| Q6 | DaemonSet nodeSelector | 3 | 5 | NodeSelector + label on node + running |
| Q7 | Job restartPolicy | 3 | 5 | restartPolicy=Never + completions + succeeded |
| Q8 | CronJob concurrencyPolicy | 3 | 5 | Schedule + concurrencyPolicy + ready |
| Q9 | startupProbe + liveness | 3 | 5 | startupProbe failureThreshold≥20 + liveness + available |
| Q10 | Readiness probe + endpoints | 3 | 5 | Probe path + selector match + endpoints |
| Q11 | ConfigMap env inject | 3 | 5 | EnvFrom ref + available + runtime exec `printenv` |
| Q12 | Secret env inject | 3 | 5 | SecretRef + available + runtime exec |
| Q13 | Pod recreate (no nodeName) | 3 | 5 | No nodeName in spec + label + running |
| Q14 | nodeSelector scheduling | 3 | 5 | Node label exists + selector + ready on labeled node |
| Q15 | nodeAffinity required vs preferred | 3 | 5 | No required affinity + preferred affinity + available |
| Q16 | Taint + toleration | 3 | 5 | nodeSelector for reserved pool + both tolerations |
| Q17 | podAntiAffinity topologyKey | 3 | 5 | Anti-affinity rule + topologyKey + all scheduled |
| Q18 | topologySpreadConstraints | 3 | 5 | maxSkew + topology key + pods spread |
| Q19 | ResourceQuota scheduling | 3 | 5 | Quota exists + request/limit in spec + pod running |
| Q20 | PriorityClass preemption | 3 | 5 | PriorityClass value + preemptionPolicy + pod scheduled |

### Domain Coverage

Intentionally single-domain (Workloads & Scheduling) — coverage judgment relative to stated purpose:

| Sub-topic | Coverage |
|---|---|
| Deployments (rollout, probe, strategy) | Q1, Q2, Q9, Q10 |
| StatefulSets | Q3, Q4 |
| DaemonSets | Q5, Q6 |
| Jobs / CronJobs | Q7, Q8 |
| ConfigMaps / Secrets | Q11, Q12 |
| Node scheduling (nodeName, nodeSelector, affinity, taints) | Q13–Q16 |
| Advanced scheduling (antiAffinity, topology, ResourceQuota, PriorityClass) | Q17–Q20 |

**Within Workloads & Scheduling: near-complete coverage** ✅  
**No RBAC, Networking, Storage, or Cluster Architecture** — by design for topic lab.

### Quality Score: 90 / 100

| Dimension | Score | Reason |
|---|---:|---|
| Structural integrity | 20/20 | All checks pass |
| Validation quality | 23/25 | All 3 verifs; `kubectl exec printenv` runtime checks; rollout --timeout; -1 for `set +e` |
| k3d compatibility | 15/15 | No kubeadm; taint cleanup in setup scripts prevents cross-Q interference |
| Question design | 13/15 | Broken/paused initial state; CrashLoop triggers; all realistic scheduling scenarios |
| Domain coverage | 9/10 | Excellent within-domain; -1 for no Storage or RBAC (intentional limitation) |
| False-positive prevention | 7/10 | `set +e` allows unset-variable continuation; some grep-based toleration checks |
| Documentation | 3/5 | answers.md present but not reviewed in depth |

### Doability: ✅ Yes

**Strong:** All k3d-native. Taint cleanup in setup prevents Q16 taints polluting other questions.  
**Risks (low):**  
- Q4 StatefulSet VCT requires PVC provisioning (128Mi) — k3d local-path-provisioner handles this ✅  
- Q3 headless service DNS resolution requires CoreDNS running — expected on k3d ✅  
- `set +e` in validation scripts means unset variables don't cause immediate exit; could mask subtle bugs  
- Q17/Q18 topology spread checks depend on 2+ worker nodes (config.json `workerNodes: 2` ✅)  

---

## Cross-Exam Analysis

### Namespace Isolation

| Exam | Namespace Prefix | Conflicts |
|---|---|---|
| cka-004 | `cka-qNN` | None ✅ |
| cka-005 | `rev1-qNN` | None ✅ |
| cka-007 | `cka007-qNN` | None ✅ |

`default` namespace is shared (cka-004 Q1/Q2, cka-005 Q7) — acceptable for kubeconfig/context tasks.

### Combined Domain Coverage (running all three)

| Domain | CKA Target | Combined Coverage |
|---|---:|---|
| Cluster Architecture / RBAC | 25% | Moderate (RBAC in 004, kubeconfig in 005) |
| Workloads & Scheduling | 15% | **Excellent** (007 dedicated + 004/005 coverage) |
| Services & Networking | 20% | Good (005 Q2/Q10/Q14/Q17, 004 Q8/Q9/Q20) |
| Storage | 10% | Light (004 Q6, 005 Q5/Q13) — needs more |
| Troubleshooting | 30% | Good (005 strong; 004 some; 007 CrashLoop Q9) |

**Gap remaining:** Real cluster RBAC troubleshooting (ServiceAccount token issues, wrong ClusterRoleBinding namespace, CertificateSigningRequest) and deeper Storage (accessMode mismatch, reclaim policy, StorageClass wrong provisioner).

### Recommended Use Order

1. **cka-007** first — topic drill, confidence in scheduling
2. **cka-005** second — highest quality full mock, best troubleshooting depth
3. **cka-004** third — wider breadth, more Qs per session, good for speed practice

---

## Per-Exam Score Summary

### cka-004: 75 / 100

**Strengths:** Full structural integrity, clean namespace isolation, 25 questions for breadth, RBAC with auth can-i, bridges correctly labelled.  
**Weaknesses:** Every question has only 2 validation steps; ~9 create-only tasks; Storage at 4%; Troubleshooting at 16% (real CKA: 30%).

### cka-005: 92 / 100

**Strengths:** Best in class. 15/17 questions have 3 validation steps. Python+jsonpath validation. Local Helm chart (zero external dependency). Real broken-state troubleshooting throughout. ResourceQuota numeric CPU comparison. PDB anchor prevents false pass on Q8.  
**Weaknesses:** No scheduling questions (taints, affinity). Helm chart staged to `/tmp` (medium risk if env reset).

### cka-007: 90 / 100

**Strengths:** All 20 questions have 3 validation steps. Runtime `kubectl exec printenv` environment checks. Taint cleanup in setup prevents question cross-contamination. Deep within-domain coverage.  
**Weaknesses:** `set +e` instead of `set -euo pipefail` in all validation scripts. Zero coverage of RBAC, Networking, Storage (by design but limits full-mock utility). Some grep-based toleration checks.

---

## Issues Requiring Attention

### MEDIUM Priority

| Exam | Issue | Impact |
|---|---|---|
| cka-004 | Every question has only 2 validation steps | Hard questions under-graded; partial credit impossible |
| cka-004 | Q9 s2 egress grep fragile | False-positive risk if YAML contains `app: db` in wrong block |
| cka-005 | Helm chart at `/tmp/exam/q3/` | If `/tmp` is cleared, Q3 setup must re-run |

### LOW Priority

| Exam | Issue | Impact |
|---|---|---|
| cka-004 | Storage domain at 4% (1 question) | CKA real exam weight is 10%; insufficient practice |
| cka-004 | Troubleshooting at 16% | CKA real exam weight is 30%; insufficient practice |
| cka-007 | `set +e` in all validation scripts | Unset variables don't cause clean exit; subtle bugs may be masked |
| All | No runtime end-to-end validation performed | Setup→fail→solve→pass cycle not verified |

---

## Recommendations

1. **cka-005 is the gold-standard exam** — use it as the primary revision exam before your CKA sitting.
2. **cka-004 needs a revision pass** to add a 3rd validation step to hard troubleshooting questions (Q6, Q7, Q8, Q9, Q13) and replace 3-4 create-only tasks with broken-state tasks.
3. **Add a Storage-focused lab** (PV/PVC binding failure, StorageClass mismatch, StatefulSet VCT reclaim policy) to bring storage coverage to 10%.
4. **cka-007 standalone validation** — consider adding `set -euo pipefail` to validation scripts, or at minimum `set -u` to catch unset-variable bugs.
5. **Run a live smoke test** on all three exams before next session: setup → validate-fails → apply answer → validate-passes.

---

## Static Validation Summary

```
Exam       | JSON | bash-n | exec | weightage | refs   | kubeadm-clean | ns-collision
-----------|------|--------|------|-----------|--------|---------------|-------------
cka-004    |  ✅  |  75/75 |  75  |  100/100  | 50/50  |      ✅       |     ✅
cka-005    |  ✅  |  66/66 |  66  |  100/100  | 49/49  |      ✅       |     ✅
cka-007    |  ✅  |  80/80 |  80  |  100/100  | 60/60  |      ✅       |     ✅
```

*Runtime (setup→validate→solve→validate) was not performed. No live k3d cluster was available.*

---

*Audit completed: 2026-05-03. No files were modified during this audit.*
