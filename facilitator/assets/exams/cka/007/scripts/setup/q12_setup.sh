#!/bin/bash
set -euo pipefail
NS=cka-q12
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
kubectl create secret generic db-credentials -n "$NS" --from-literal=password=s3cr3t >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-worker
  namespace: cka-q12
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-worker
  template:
    metadata:
      labels:
        app: payment-worker
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh","-c","while true; do echo running; sleep 30; done"]
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: pwd
YAML
exit 0
