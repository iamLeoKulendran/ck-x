# CKA-005 Implementation Notes

Reference these before generating any file under `facilitator/assets/exams/cka/005/`.

---

## Model Strategy

- **Sonnet** — all implementation work (config.json, assessment.json, setup scripts, validation scripts, answers.md, labs.json update)
- **Opus** — final quality review only, after all files are generated and validated

---

## Per-Question Notes

### Q3 — Helm revision numbers
Do not assert an exact revision number in validation. After rollback to rev 1 (creates rev 3) and then upgrade (creates rev 4), the final revision number is 4, not 3. Validate only:
- `helm status web-frontend` shows `deployed`
- Deployment image tag is `1.27`
- 3 Ready replicas

### Q6 — Real CrashLoopBackOff via readOnly volumeMount
Setup pod must use `busybox:1.36` with a command that actually writes on startup so readOnly causes a crash:
```bash
command: ["sh", "-c", "while true; do echo $(date) >> /data/output/log; sleep 2; done"]
```
The volumeMount `readOnly: true` causes Permission denied → container exits → CrashLoopBackOff.

### Q7 — Do not modify `~/.kube/config`
Merge destination is `/tmp/exam/q7/merged-config.yaml`. Never touch `~/.kube/config` — it is the candidate's active config for all other questions. Setup generates two kubeconfig files from the existing cluster config with renamed contexts (`dev-context`, `prod-context`).

### Q10 — NetworkPolicy: spec-shape validation only
K3s uses Flannel. NetworkPolicy is NOT enforced at the network level. All validation must be spec-shape via jsonpath. Check all four facets per rule: podSelector labels, peer selector labels, port number, protocol. Do not test live traffic.

### Q13 — Create `standard` StorageClass
k3d default SC is `local-path`. The question uses `standard` as the target (to differ from Q5 which uses `local-path`). Setup must create:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

### Q8 — Do not hardcode node name
Setup must detect the actual worker node at runtime and write it to `/tmp/exam/q8/target-node.txt`:
```bash
NODE=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}')
echo "$NODE" > /tmp/exam/q8/target-node.txt
```
Question text directs the candidate to read that file. Validation also reads from the same file — never hardcode `node01`.

### Q11 — Deployment not standalone Pod
Setup creates Deployment `batch-worker` (not a standalone Pod) with CPU requests set high enough to trigger ResourceQuota exhaustion. Candidate patches the Deployment's container resources. Validation checks:
1. Deployment `batch-worker` has `availableReplicas >= 1`
2. Pod backing the Deployment is Running
3. ResourceQuota `used.requests.cpu < hard.requests.cpu`

### Q15 — Use PVC instead of hostPath
Use PVC `report-data` (`storageClassName: local-path`, `ReadWriteOnce`, `1Gi`) mounted at `/data/reports`. Setup creates the PVC and a broken CronJob. Validation:
1. Check CronJob spec (schedule `*/5 * * * *`, history limits, volumeMount at `/data/reports`)
2. `kubectl create job --from=cronjob/report-gen q15-verify -n rev1-q15`
3. Wait up to 60s for Job completion
4. Create a debug Pod (`busybox:1.36`) mounting the same PVC; `kubectl exec` to confirm `/data/reports/output.txt` is non-empty
5. Delete debug Pod after check

### Q17 — Validate string targetPort names
`Service.spec.ports[].targetPort` must be the string name (`"http"`, `"metrics"`), not a numeric value (`8080`, `9090`). Both are valid Kubernetes but using strings is the test point. Validate with jsonpath:
```bash
kubectl get svc dual-svc -n rev1-q17 -o jsonpath='{.spec.ports[?(@.name=="http")].targetPort}'
# must return "http", not "8080"
```

---

## General Rules

- All setup scripts: `#!/bin/bash`, `set -euo pipefail`, idempotent, non-interactive
- All validation scripts: return `exit 0` for pass, non-zero for fail
- All questions use `machineHostname: ckad9999`
- No real kubeadm tasks
- Total marks = 100 exactly (15 × 6 + 2 × 5)
- Setup must NOT cause any validation to pass before candidate acts
- Run `bash -n` on every `.sh` file before final commit
- Run `python3 -m json.tool` on every `.json` file before final commit
- Write `validation-report.md` after all files are generated

---

## Known Duplicate Risks (avoid when writing setup object names)

| Pattern | Already used in lab | Avoid exact copy |
|---------|---------------------|-----------------|
| Service selector fix | Lab 004 Q8 | Q2 uses targetPort fix, not selector fix |
| readiness probe path | Lab 007 Q2 | Q14 uses port, not path |
| StatefulSet volumeClaimTemplates create | Lab 007 Q4 | Q13 is troubleshoot broken SC, not create |
| ResourceQuota + resize | Lab 007 Q19 | Q11 uses Deployment (not standalone Pod); candidate must DISCOVER the cause via events |
| PVC storageClassName fix | Q5 (same lab) | Q13 uses different SC name (`premium-nvme → standard`) |
