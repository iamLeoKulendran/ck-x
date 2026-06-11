#!/bin/bash
set -euo pipefail

NS="release-pinning"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset: recreate the deployment with the mutable tag reference
kubectl -n "$NS" delete deployment web-frontend --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: release-pinning
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
YAML

kubectl -n "$NS" rollout status deployment/web-frontend --timeout=180s >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q12
rm -f /tmp/exam/q12/pinned-image.txt

echo "Question 12 setup complete"
