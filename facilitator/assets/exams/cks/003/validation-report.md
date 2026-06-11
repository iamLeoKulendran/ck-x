# Validation Report - cks-003 (Mock Exam - CKS - 2)

Generated: 2026-06-11 (Phase 1I)

## Lab summary

| Property | Value |
| --- | --- |
| Lab ID | cks-003 |
| Name | Mock Exam - CKS - 2 |
| Questions | 16 |
| Duration | 120 minutes |
| Difficulty | Hard |
| Total marks | 100 |
| Validation scripts | 46 (2-3 per question) |
| machineHostname | ckad9999 (all questions) |
| Bridge/simulation tasks | 2 (Q7, Q14 - clearly labeled SIMULATED) |

## Domain coverage vs official CKS weights

| Domain | Official | cks-003 marks | Questions |
| --- | ---: | ---: | --- |
| Cluster Setup | 15% | 15 | Q1 (8), Q2 (7) |
| Cluster Hardening | 15% | 15 | Q3 (5), Q4 (5), Q5 (5) |
| System Hardening | 10% | 10 | Q6 (5), Q7 (5) |
| Minimize Microservice Vulnerabilities | 20% | 20 | Q8 (7), Q9 (7), Q10 (6) |
| Supply Chain Security | 20% | 20 | Q11 (7), Q12 (7), Q13 (6) |
| Monitoring, Logging and Runtime Security | 20% | 20 | Q14 (7), Q15 (7), Q16 (6) |
| **Total** | 100% | **100** | 16 questions |

## Question tier classification

| Q | Topic | Tier | Toolbox |
| --- | --- | --- | --- |
| 1 | Egress NetworkPolicy with namespaceSelector + DNS | Tier 1 (live) | - |
| 2 | kube-bench CIS report analysis (planted output) | Tier 1 (static artifact) | kube-bench output |
| 3 | CSR-based user provisioning + least-privilege RBAC | Tier 1 (live) | openssl |
| 4 | ServiceAccount automount off + projected audience-bound token | Tier 1 (live) | - |
| 5 | Anonymous-access ClusterRoleBinding audit and revocation | Tier 1 (live) | - |
| 6 | Host namespace / hostPath de-privileging | Tier 1 (live) | - |
| 7 | Host service footprint audit | **Bridge (SIMULATED, planted files)** | - |
| 8 | runAsNonRoot CreateContainerConfigError troubleshooting | Tier 1 (live) | - |
| 9 | Pod-to-pod TLS with mounted secret + nginx TLS config | Tier 1 (live) | - |
| 10 | ValidatingAdmissionPolicy (CEL) denying hostPath | Tier 1 (live) | - |
| 11 | Manifest misconfiguration scan + hardening | Tier 1 (live + artifacts) | trivy, kubesec |
| 12 | Image digest pinning | Tier 1 (live) | - |
| 13 | SBOM generation + SBOM vulnerability scan + upgrade | Tier 1 (live + artifacts) | syft, trivy |
| 14 | Audit policy authoring | **Bridge (SIMULATED, file only)** | yq (validation) |
| 15 | Malicious CronJob hunt, suspension, RBAC revocation | Tier 1 (live) | - |
| 16 | Credential leak in logs + secret rotation | Tier 1 (live) | - |

Jumphost toolbox is exercised in Q2 (kube-bench output), Q11 (trivy config + kubesec), Q13 (syft + trivy sbom), Q14 (yq) - 4 questions, satisfying the >= 3 requirement.

## Structural validation results

All run from the repository root on 2026-06-11:

| Check | Result |
| --- | --- |
| `python3 -m json.tool` labs.json / config.json / assessment.json | PASS |
| `bash -n` on all 62 scripts (16 setup + 46 validation) | PASS |
| All setup/validation scripts executable | PASS (0 non-executable) |
| `validate_ckx_cks_lab.sh facilitator/assets/exams/cks/003` | PASS, 0 warnings (questions=16, weightage=100, validations=46) |
| Orphan validation scripts | None (46 on disk, 46 referenced) |
| Total weightage | Exactly 100 |
| Validations per question | 2-3 (within the 2-5 rule) |
| `machineHostname: ckad9999` on every question | PASS |
| No `assets.tar.gz` committed | PASS |
| Registry entry cks-003 matches lab | PASS |
| Registry backup | `/tmp/labs.json.bak-phase1i` |

## False-positive audit (fresh broken state must fail every validation)

| Q | Why every validation fails before solving |
| --- | --- |
| 1 | Setup deletes all NetworkPolicies in `edge-zone`; s1 requires the policy object, s2/s3 guard on its existence before testing traffic. |
| 2 | Setup removes `failed-checks.txt` and `remediation-1.2.1.txt`. |
| 3 | Setup deletes the CSR, Role, RoleBinding, and key/csr/crt files. |
| 4 | Setup deletes `inventory-sa` and recreates the deployment with the default SA and no projected volume; s3 also requires the vault token file to be readable. |
| 5 | Setup recreates the offending CRB/ClusterRole and removes `findings.txt`; s2/s3 carry positive guards on `findings.txt`, and s2 fails while the CRB exists. |
| 6 | Setup recreates the deployment with `hostNetwork`, `hostPID`, and a hostPath volume; s3 guards on hostNetwork before checking runtime state. |
| 7 | Setup removes both answer files. |
| 8 | Setup recreates the broken state (root image + runAsNonRoot -> CreateContainerConfigError) and targetPort 80; s1 fails on image, s2 on rollout, s3 on targetPort. |
| 9 | Setup deletes the `orders-tls` secret and recreates the plain-HTTP deployment and the port-80 service. |
| 10 | Setup deletes the VAP, binding, `safe-cache`, and `rejected.txt`; the live probe in s2 would be accepted with no policy, which also fails the check. |
| 11 | Setup removes all reports and the fixed manifest and deletes the `webhook-gw` deployment. |
| 12 | Setup removes `pinned-image.txt` and recreates the tag-based deployment; s2/s3 fail on the non-digest image. |
| 13 | Setup removes the SBOM artifacts and recreates the deployment on `nginx:1.25-alpine`. |
| 14 | Setup removes `audit-policy.yaml`. |
| 15 | Setup applies `suspend: false` to all CronJobs, recreates the CRB/ClusterRole, and removes `findings.txt`. |
| 16 | Setup restores the leaked secret value and the leaky startup command and removes `leaked-token.txt`; s3 fails because logs contain `ntfy_` and lack `token loaded`. |

Positive end-state coverage: every question has at least one validation asserting a positive final state (object exists with exact fields, workload Ready, runtime connectivity succeeds, or answer file holds the correct content). RBAC validations (Q3, Q5, Q15) test allowed AND denied behavior with `kubectl auth can-i`; the NetworkPolicy validation (Q1) tests the allowed path and the denied path; the admission-policy validation (Q10) tests rejection of a violating pod and acceptance of a compliant pod.

## Runtime validation

**SKIPPED** - the CK-X stack was not running at generation time (no containers up). Static validation only. When the stack is up, run per question on the jumphost:

1. `bash scripts/setup/qN_setup.sh` - all validations must fail.
2. Apply the matching `answers.md` solution.
3. Re-run the validations - all must pass.

External-network dependencies to verify at runtime: image pulls (`nginxinc/nginx-unprivileged:1.27-alpine`, `curlimages/curl:8.5.0`, `busybox:1.36`, `nginx:1.25/1.27-alpine`), trivy DB download (Q11, Q13), syft registry access (Q13).

## Phase 4 UX compatibility (static check)

- Question weight display: cks-003 has no direct per-question weightage field, so `getQuestionWeight` derives the sum of verification weightages (6 or 7) and, with `config.totalMarks = 100`, renders `6 marks (6%)` / `7 marks (7%)`.
- Answers locked before evaluation: facilitator `getExamAnswers` returns 403 unless exam status is `EVALUATED` - lab-agnostic, applies to cks-003.
- Answers visible after evaluation: served from `examInfo.config.answers`; cks-003 `config.json` points to `assets/exams/cks/003/answers.md`, which exists.
- Runtime UI confirmation pending until the stack is rebuilt with the new lab.

## Originality statement

All 16 scenarios, namespaces, object names, and failure modes are original and were checked against cks-001 and cks-002 to avoid duplication. No Killer.sh, PSI, CNCF, Linux Foundation, or real exam content was used. "Killer.sh-grade" refers to format, rigor, timing, and scoring only.

## Rebuild / restart

```bash
docker compose build facilitator
docker compose up -d facilitator nginx
```
