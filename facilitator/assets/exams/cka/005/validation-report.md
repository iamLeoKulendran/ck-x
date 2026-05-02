# Validation Report — cka-005

**Lab:** Mock Exam - CKA revision -1  
**Date:** 2026-05-02  
**Status:** PASS — safe to test in CK-X UI

---

## Skill Validator Output

```
OK: JSON syntax valid
OK: Shell syntax valid
WARNING: q5: likely toy create-only task; hard mocks should be more scenario/troubleshooting heavy
OK: structural validation passed, registry=facilitator/assets/exams/labs.json, questions=17, weightage=100, validations=49
OK: CK-X lab validation completed
```

**Q5 warning is a false positive.** Q5 requires the candidate to diagnose a PVC stuck in `Pending` due to a missing `StorageClass`, delete it, recreate with the correct class, and deploy a Pod that mounts the PVC. This is a storage troubleshooting scenario.

---

## Structural Checks

| Check | Result |
|---|---|
| config.json valid JSON | PASS |
| assessment.json valid JSON | PASS |
| labs.json valid JSON after update | PASS |
| Total questions | 17 |
| Total weightage | 100 |
| Total validation scripts | 49 |
| Validation scripts per question | 2–3 each (all within 2–5 range) |
| All verificationScriptFile references exist | PASS |
| bash -n syntax check (66 scripts) | 0 errors |
| chmod +x applied | PASS |

---

## Domain Coverage

| Domain | Questions | Target |
|---|---|---|
| Troubleshooting | Q1, Q2, Q5, Q6, Q8, Q11, Q13, Q14 | 30% |
| Cluster Architecture / Config | Q3, Q7, Q12, Q16 | 25% |
| Workloads & Scheduling | Q4, Q9, Q15 | 15% |
| Services & Networking | Q2, Q10, Q17 | 20% |
| Storage | Q5, Q13, Q15 | 10% |

---

## Marks Distribution

| Questions | Marks | Count | Subtotal |
|---|---|---|---|
| Q1–Q4, Q6–Q8, Q10–Q17 | 6 each | 15 | 90 |
| Q5, Q9 | 5 each | 2 | 10 |
| **Total** | | **17** | **100** |

---

## k3d/K3s Backend Notes

| Question | Risk | Mitigation |
|---|---|---|
| Q3 (Helm rollback) | Local chart, no external repo dependency | Setup builds chart from scratch |
| Q8 (Node drain) | Node name varies by cluster | Setup writes actual node to `/tmp/exam/q8/target-node.txt` |
| Q10 (NetworkPolicy) | Flannel does not enforce NP | Validation checks spec shape only (jsonpath) |
| Q13 (StatefulSet StorageClass) | `standard` SC not native to k3d | Setup creates it with rancher.io/local-path provisioner |
| Q15 (CronJob output) | Schedule timing | Validation triggers a one-shot Job manually |

---

## False-Positive Audit

- All setup scripts create broken/incomplete initial state; no validation passes before candidate work.
- Q6: `readOnly: true` on a volume the app writes to — CrashLoopBackOff guaranteed.
- Q11: ResourceQuota exhausted at setup; batch-worker Deployment stays Pending.
- Q13: StatefulSet PVCs stuck Pending due to non-existent `premium-nvme` StorageClass.
- Q14: Deployment rollout stalled due to wrong probe port; endpoints empty.
- No pure-negative validations present.

---

## labs.json Entry

```json
{
  "id": "cka-005",
  "assetPath": "assets/exams/cka/005",
  "name": "Mock Exam - CKA revision -1",
  "category": "CKA",
  "description": "Original CKA-style mock exam covering troubleshooting, workloads, services, networking, storage, RBAC, Helm, Kustomize, and CRDs.",
  "warmUpTimeInSeconds": 360,
  "difficulty": "Hard",
  "examDurationInMinutes": 120
}
```

---

## Verdict: SAFE TO TEST IN CK-X UI
