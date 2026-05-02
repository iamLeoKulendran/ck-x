#!/bin/bash
set -euo pipefail
NS="rev1-q05"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete pod app-pod --ignore-not-found=true
kubectl -n "$NS" delete pvc app-data --ignore-not-found=true
sleep 2
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: rev1-q05
spec:
  storageClassName: fast-ssd
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
EOF
echo "Q5 setup complete"
