#!/bin/bash
set -euo pipefail

NS="system-lockdown"
REG="registry.localhost:5000/ckx/alpine:3.20"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment edge-cache --ignore-not-found=true >/dev/null 2>&1 || true

# Over-permissive starting state: extra capabilities + privilege escalation, runs as root
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: edge-cache
  namespace: system-lockdown
  labels:
    app: edge-cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: edge-cache
  template:
    metadata:
      labels:
        app: edge-cache
    spec:
      containers:
      - name: cache
        image: ${REG}
        command: ["sleep", "infinity"]
        securityContext:
          allowPrivilegeEscalation: true
          capabilities:
            add: ["SYS_ADMIN", "NET_RAW"]
YAML

kubectl -n "$NS" rollout status deployment/edge-cache --timeout=120s >/dev/null 2>&1 || true

echo "Question 6 setup complete"
