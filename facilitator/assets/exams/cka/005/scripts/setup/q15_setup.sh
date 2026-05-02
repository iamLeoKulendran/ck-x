#!/bin/bash
set -euo pipefail
NS="rev1-q15"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete cronjob report-gen --ignore-not-found=true
kubectl -n "$NS" delete pvc report-data --ignore-not-found=true
kubectl -n "$NS" delete pod q15-debug --ignore-not-found=true
sleep 2

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: report-data
  namespace: rev1-q15
spec:
  storageClassName: local-path
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report-gen
  namespace: rev1-q15
spec:
  schedule: "0 0 1 * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: reporter
            image: busybox:1.36
            command: ["sh", "-c", "echo report done"]
          restartPolicy: OnFailure
EOF

echo "Q15 setup complete"
