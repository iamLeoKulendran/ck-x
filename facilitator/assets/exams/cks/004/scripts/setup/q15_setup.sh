#!/bin/bash
set -euo pipefail

NS="runtime-soc"
REG="registry.localhost:5000/ckx/alpine:3.20"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment ingest-api --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete networkpolicy --all --ignore-not-found=true >/dev/null 2>&1 || true

# Compromised starting state: legit api container + injected privileged debug sidecar
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingest-api
  namespace: runtime-soc
  labels:
    app: ingest-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ingest-api
  template:
    metadata:
      labels:
        app: ingest-api
    spec:
      containers:
      - name: api
        image: ${REG}
        command: ["sleep", "infinity"]
      - name: debug
        image: registry.localhost:5000/ckx/alpine:3.20
        command: ["sleep", "infinity"]
        securityContext:
          privileged: true
YAML

kubectl -n "$NS" rollout status deployment/ingest-api --timeout=120s >/dev/null 2>&1 || true

echo "Question 15 setup complete"
