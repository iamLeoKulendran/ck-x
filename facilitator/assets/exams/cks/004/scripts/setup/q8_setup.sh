#!/bin/bash
set -euo pipefail

NS="microsvc-restricted"
REG="registry.localhost:5000/ckx/alpine:3.20"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset namespace PSA labels to a non-restricted baseline so the question starts non-compliant
kubectl label namespace "$NS" \
  pod-security.kubernetes.io/enforce- \
  pod-security.kubernetes.io/enforce-version- \
  pod-security.kubernetes.io/warn- \
  pod-security.kubernetes.io/warn-version- \
  pod-security.kubernetes.io/audit- \
  pod-security.kubernetes.io/audit-version- >/dev/null 2>&1 || true

kubectl -n "$NS" delete deployment orders-ui --ignore-not-found=true >/dev/null 2>&1 || true

# Non-compliant starting deployment (no restricted securityContext)
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-ui
  namespace: microsvc-restricted
  labels:
    app: orders-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orders-ui
  template:
    metadata:
      labels:
        app: orders-ui
    spec:
      containers:
      - name: ui
        image: ${REG}
        command: ["sleep", "infinity"]
YAML

kubectl -n "$NS" rollout status deployment/orders-ui --timeout=120s >/dev/null 2>&1 || true

echo "Question 8 setup complete"
