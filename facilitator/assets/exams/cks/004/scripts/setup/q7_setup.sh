#!/bin/bash
set -euo pipefail

NS="syscall-lockdown"
REG="registry.localhost:5000/ckx/alpine:3.20"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment metrics-shipper --ignore-not-found=true >/dev/null 2>&1 || true

# Insecure starting state: seccomp explicitly Unconfined
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-shipper
  namespace: syscall-lockdown
  labels:
    app: metrics-shipper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: metrics-shipper
  template:
    metadata:
      labels:
        app: metrics-shipper
    spec:
      securityContext:
        seccompProfile:
          type: Unconfined
      containers:
      - name: shipper
        image: ${REG}
        command: ["sleep", "infinity"]
YAML

kubectl -n "$NS" rollout status deployment/metrics-shipper --timeout=120s >/dev/null 2>&1 || true

echo "Question 7 setup complete"
