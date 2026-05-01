#!/bin/bash
set -euo pipefail
NS=cka-q13
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete job q13-pi -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: q13-pi
  namespace: $NS
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pi
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
EOF
exit 0
