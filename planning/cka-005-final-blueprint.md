# CKA-005 Final Blueprint: Mock Exam - CKA revision -1

**Status:** APPROVED (Opus final review: PASS, 93/100)
**Lab ID:** `cka-005` | **Folder:** `facilitator/assets/exams/cka/005/`
**Duration:** 120 min | **Questions:** 17 | **Marks:** 100 | **Difficulty:** Medium to Hard
**Workers:** 2 | **Hostname:** `ckad9999`
**Marks scheme:** 15 × 6 + 2 × 5 = 100 (Q5 and Q9 are the 5-mark questions)

---

## Question Plan

| Q# | Domain | Scenario | Marks | Scripts | Namespace |
|----|--------|----------|:-----:|:-------:|-----------|
| 1 | Troubleshooting | Pod `web-init` stuck `Init:0/1`. Init container loops `nc -z db-service.rev1-q01.svc.cluster.local 5432`. Service `db-service` does not exist. Without modifying the Pod, create ClusterIP Service `db-service` (selector `app=db`, port 5432→targetPort 80) plus backing Pod (`nginx:1.27`, label `app=db`). Verify init completes and main container reaches Running. | 6 | 3 | rev1-q01 |
| 2 | Services & Networking | Service `frontend-svc` has port 80→targetPort 80. Backing Pods (`gcr.io/google-samples/hello-app:1.0`) are Running, Endpoints populated, but `curl` returns connection refused — app listens on 8080. Patch Service targetPort to 8080. Do not modify the Deployment. | 6 | 3 | rev1-q02 |
| 3 | Cluster Architecture | Helm release `web-frontend` is at revision 2 with Pods in ImagePullBackOff (bad tag). Revision 1 was healthy. Chart tarball at `/tmp/exam/q3/chart.tgz`, values file at `/tmp/exam/q3/good-values.yaml` (`replicaCount: 3`, `image.tag: 1.27`). Roll back to revision 1, then upgrade using that values file. Verify release is deployed with 3 Ready replicas. | 6 | 3 | rev1-q03 |
| 4 | Workloads & Scheduling | Create Deployment `config-loader` (3 replicas, `nginx:1.27`) with init container (`busybox:1.36`) that copies `/input/app.conf` from a ConfigMap-backed volume to `/shared/app.conf` on an emptyDir. Main container mounts same emptyDir at `/etc/app/` and must reach Running. | 6 | 3 | rev1-q04 |
| 5 | Storage | PVC `app-data` stuck Pending: `storageClassName: fast-ssd` does not exist; only `local-path` is available. Delete PVC, recreate with `storageClassName: local-path`, mount into a Pod (`nginx:1.27`). Verify PVC is Bound. | 5 | 2 | rev1-q05 |
| 6 | Troubleshooting | Pod `data-processor` (`busybox:1.36`) in CrashLoopBackOff. Logs show Permission denied writing to `/data/output`. Root cause: emptyDir volumeMount has `readOnly: true`. Remove the flag. Verify pod reaches Running. | 6 | 3 | rev1-q06 |
| 7 | Cluster Architecture | Two kubeconfigs staged at `/tmp/exam/q7/kube-dev` and `/tmp/exam/q7/kube-prod`. Merge into `/tmp/exam/q7/merged-config.yaml`. Do NOT modify `~/.kube/config`. Set `prod-context` as current context. Validation verifies both contexts exist and current-context is prod-context. | 6 | 3 | rev1-q07 |
| 8 | Troubleshooting | Setup writes the target worker node name to `/tmp/exam/q8/target-node.txt`. `kubectl drain <node> --ignore-daemonsets` fails: PodDisruptionBudget `api-pdb` has `minAvailable: 2`, blocking eviction of its 2-replica Deployment. Read the node name from that file. Patch PDB `minAvailable` to 1, drain the node, uncordon it. | 6 | 3 | rev1-q08 |
| 9 | Workloads & Scheduling | DaemonSet `log-collector` has `updateStrategy.type: OnDelete`. Change to RollingUpdate with `maxUnavailable: 1`. Update image from `nginx:1.27` to `nginx:1.28`. Verify rollout completes. | 5 | 2 | rev1-q09 |
| 10 | Services & Networking | Create NetworkPolicy `api-policy` in `rev1-q10` for pods `app=api`: allow ingress from `app=frontend` on port 8080; allow egress to `app=db` on port 5432; deny all other ingress/egress. | 6 | 3 | rev1-q10 |
| 11 | Troubleshooting | Deployment `batch-worker` has 0/1 Available. Its Pod is stuck Pending with no obvious error. Use describe/events to find namespace ResourceQuota CPU exhaustion. Patch the Deployment CPU requests/limits to fit within the quota. Verify Deployment Available and Pod Running. | 6 | 3 | rev1-q11 |
| 12 | Cluster Architecture | Build Kustomize overlay at `/tmp/exam/q12/overlay/`: configMapGenerator from `/tmp/exam/q12/app.properties`; namePrefix `prod-`; namespace `rev1-q12`. Apply with `kubectl apply -k`. Verify ConfigMap exists. | 6 | 3 | rev1-q12 |
| 13 | Storage | StatefulSet `cache-cluster` pods stuck Pending: `volumeClaimTemplates` references `storageClassName: premium-nvme` (nonexistent). Delete StatefulSet, recreate with `storageClassName: standard`. Verify pods Running, PVCs Bound. | 6 | 3 | rev1-q13 |
| 14 | Troubleshooting | Deployment `api-server` shows 0/3 READY. Readiness probe checks port 80; app (`gcr.io/google-samples/hello-app:1.0`) listens on 8080. Service `api-svc` also has targetPort 80. Fix both probe port and Service targetPort to 8080. Verify 3/3 ready, endpoints populated. | 6 | 3 | rev1-q14 |
| 15 | Workloads & Scheduling | Fix CronJob `report-gen`: schedule `*/5 * * * *`; command appends timestamp to `/data/reports/output.txt` via PVC `report-data` mounted at `/data/reports`; `successfulJobsHistoryLimit: 3`; `failedJobsHistoryLimit: 1`. Validation triggers a one-shot Job from the CronJob and reads the output file via a debug Pod mounting the same PVC. | 6 | 3 | rev1-q15 |
| 16 | Cluster Architecture | CRD manifest at `/tmp/exam/q16/databasebackup-crd.yaml`. Install CRD. Create two `DatabaseBackup` CRs in `rev1-q16`: `weekly-pg` (targetDB: postgres, schedule: "0 2 * * 0", retentionDays: 7) and `daily-mysql` (targetDB: mysql, schedule: "0 3 * * *", retentionDays: 3). Write kubectl command to `/tmp/exam/q16/list.sh` listing all DatabaseBackups across namespaces with custom columns NAME,TARGET,SCHEDULE. Make it executable. | 6 | 3 | rev1-q16 |
| 17 | Services & Networking | Create Deployment `dual-svc-app` (3 replicas, `nginx:1.27`) with named container ports: `http`→8080 and `metrics`→9090. Create ClusterIP Service `dual-svc` using named targetPorts: port 80→`targetPort: http` and port 9090→`targetPort: metrics`. Verify Service has 3 endpoint addresses. | 6 | 3 | rev1-q17 |

---

## Domain Coverage

| Domain | Target | Questions | Marks | Actual |
|--------|:------:|:---------:|:-----:|:------:|
| Troubleshooting | 30% | Q1, Q6, Q8, Q11, Q14 | 30 | 30% |
| Cluster Architecture, Installation & Config | 25% | Q3, Q7, Q12, Q16 | 24 | 24% |
| Services & Networking | 20% | Q2, Q10, Q17 | 18 | 18% |
| Workloads & Scheduling | 15% | Q4, Q9, Q15 | 17 | 17% |
| Storage | 10% | Q5, Q13 | 11 | 11% |
| **Total** | **100%** | **17** | **100** | **100%** |

---

## Opus Final Review Summary

- **Verdict:** PASS — Ready for implementation
- **Score:** 93/100
- **Blocker resolved:** Q7 merge destination changed from `~/.kube/config` to `/tmp/exam/q7/merged-config.yaml`
- **All v1/v2 patches applied:** Q2 symptom fix, Q3 wording, Q9 image swap, Q14 port, Q17 named-port assertion
- **Remaining items:** 4 polish notes addressed in implementation notes (non-blocking)
