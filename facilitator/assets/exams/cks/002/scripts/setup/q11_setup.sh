#!/bin/bash
set -euo pipefail

NS="image-audit"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/exam/q11
rm -f /tmp/exam/q11/nginx.json /tmp/exam/q11/python.json /tmp/exam/q11/alpine.json /tmp/exam/q11/safe-image.txt

cat > /tmp/exam/q11/images.txt <<'LIST'
nginx:1.14.2
python:3.4-alpine
alpine:3.20
LIST

# Broken state: release-app runs the legacy vulnerable image
kubectl -n "$NS" delete deployment release-app --ignore-not-found=true >/dev/null 2>&1 || true
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: release-app
  namespace: image-audit
  labels:
    app: release-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: release-app
  template:
    metadata:
      labels:
        app: release-app
    spec:
      containers:
      - name: app
        image: nginx:1.14.2
        command: ["/bin/sh","-c","sleep 86400"]
YAML

kubectl -n "$NS" rollout status deployment/release-app --timeout=180s >/dev/null 2>&1 || true

echo "Question 11 setup complete"
