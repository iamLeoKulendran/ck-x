#!/bin/bash
set -euo pipefail

NS="supply-frontend"
REG="registry.localhost:5000/ckx/nginx:v1.25"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment web-frontend --ignore-not-found=true >/dev/null 2>&1 || true

# Starting state: image referenced by mutable tag
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: supply-frontend
  labels:
    app: web-frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
    spec:
      containers:
      - name: web
        image: ${REG}
        ports:
        - containerPort: 80
YAML

kubectl -n "$NS" rollout status deployment/web-frontend --timeout=120s >/dev/null 2>&1 || true

echo "Question 11 setup complete"
