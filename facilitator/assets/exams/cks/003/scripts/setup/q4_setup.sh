#!/bin/bash
set -euo pipefail

NS="stock-system"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset: remove candidate SA and recreate the deployment in its broken state
kubectl -n "$NS" delete serviceaccount inventory-sa --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete deployment inventory-api --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-api
  namespace: stock-system
  labels:
    app: inventory-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: inventory-api
  template:
    metadata:
      labels:
        app: inventory-api
    spec:
      containers:
      - name: api
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
YAML

kubectl -n "$NS" rollout status deployment/inventory-api --timeout=120s >/dev/null 2>&1 || true

echo "Question 4 setup complete"
