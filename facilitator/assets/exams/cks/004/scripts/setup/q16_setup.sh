#!/bin/bash
set -euo pipefail

NS="runtime-immutable"
REG="registry.localhost:5000/ckx/alpine:3.20"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment log-rotator --ignore-not-found=true >/dev/null 2>&1 || true

# Starting state: writes to the container root filesystem, no read-only enforcement
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-rotator
  namespace: runtime-immutable
  labels:
    app: log-rotator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-rotator
  template:
    metadata:
      labels:
        app: log-rotator
    spec:
      containers:
      - name: rotator
        image: ${REG}
        command: ["sh", "-c", "while true; do echo tick >> /var/spool/app/out.log; sleep 5; done"]
YAML

kubectl -n "$NS" rollout status deployment/log-rotator --timeout=120s >/dev/null 2>&1 || true

echo "Question 16 setup complete"
