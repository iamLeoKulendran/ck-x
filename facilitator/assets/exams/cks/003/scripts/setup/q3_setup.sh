#!/bin/bash
set -euo pipefail

NS="dev-portal"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset: remove candidate-created artifacts so the question starts unsolved
kubectl delete csr dev-lena --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete rolebinding dev-lena-pod-reader --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete role portal-pod-reader --ignore-not-found=true >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q3
rm -f /tmp/exam/q3/dev-lena.key /tmp/exam/q3/dev-lena.csr /tmp/exam/q3/dev-lena.crt

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-web
  namespace: dev-portal
  labels:
    app: portal-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portal-web
  template:
    metadata:
      labels:
        app: portal-web
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
YAML

kubectl -n "$NS" rollout status deployment/portal-web --timeout=120s >/dev/null 2>&1 || true

echo "Question 3 setup complete"
