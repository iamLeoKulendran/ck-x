#!/bin/bash
set -euo pipefail

NS="sbom-audit"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset: recreate the deployment on the old image
kubectl -n "$NS" delete deployment web-api --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api
  namespace: sbom-audit
  labels:
    app: web-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-api
  template:
    metadata:
      labels:
        app: web-api
    spec:
      containers:
      - name: api
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
YAML

kubectl -n "$NS" rollout status deployment/web-api --timeout=180s >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q13
rm -f /tmp/exam/q13/sbom.json /tmp/exam/q13/sbom-vulns.json /tmp/exam/q13/nginx-version.txt

echo "Question 13 setup complete"
