#!/bin/bash
set -euo pipefail

REG="registry.localhost:5000/ckx/nginx:v1.25"

kubectl create namespace gateway-edge --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset candidate artifacts
kubectl -n gateway-edge delete secret portal-tls --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n gateway-edge delete ingress portal-ingress --ignore-not-found=true >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q2
# Provide a self-signed cert/key for the candidate to load into a TLS secret
if [ ! -s /tmp/exam/q2/tls.crt ] || [ ! -s /tmp/exam/q2/tls.key ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout /tmp/exam/q2/tls.key -out /tmp/exam/q2/tls.crt \
    -subj "/CN=portal.ckx.local/O=ckx" >/dev/null 2>&1
fi

cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal
  namespace: gateway-edge
  labels:
    app: portal
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portal
  template:
    metadata:
      labels:
        app: portal
    spec:
      containers:
      - name: web
        image: ${REG}
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: portal-svc
  namespace: gateway-edge
spec:
  selector:
    app: portal
  ports:
  - port: 80
    targetPort: 80
YAML

kubectl -n gateway-edge rollout status deployment/portal --timeout=120s >/dev/null 2>&1 || true

echo "Question 2 setup complete"
