#!/bin/bash
set -euo pipefail

NS="payments"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Reset: remove candidate-created SA so the question starts unsolved
kubectl -n "$NS" delete serviceaccount payments-runtime --ignore-not-found=true >/dev/null 2>&1 || true

# Broken state: deployment runs on default SA with token automounted
kubectl -n "$NS" delete deployment payment-processor --ignore-not-found=true >/dev/null 2>&1 || true
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-processor
  namespace: payments
  labels:
    app: payment-processor
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-processor
  template:
    metadata:
      labels:
        app: payment-processor
    spec:
      containers:
      - name: processor
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
YAML

kubectl -n "$NS" rollout status deployment/payment-processor --timeout=120s >/dev/null 2>&1 || true

echo "Question 4 setup complete"
