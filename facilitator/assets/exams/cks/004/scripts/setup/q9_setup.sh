#!/bin/bash
set -euo pipefail

NS="payments-svc"
REG="registry.localhost:5000/ckx/nginx:v1.25"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment billing --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete secret billing-db --ignore-not-found=true >/dev/null 2>&1 || true

# Insecure starting state: plaintext password env + default SA token automounted
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing
  namespace: payments-svc
  labels:
    app: billing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing
  template:
    metadata:
      labels:
        app: billing
    spec:
      containers:
      - name: billing
        image: ${REG}
        env:
        - name: DB_PASSWORD
          value: "S3cr3t-P@ss!"
        ports:
        - containerPort: 80
YAML

kubectl -n "$NS" rollout status deployment/billing --timeout=120s >/dev/null 2>&1 || true

echo "Question 9 setup complete"
