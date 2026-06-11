#!/bin/bash
set -euo pipefail

NS="credential-hygiene"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/exam/q10
rm -f /tmp/exam/q10/found.txt

# Reset: remove the candidate-created secret
kubectl -n "$NS" delete secret db-creds --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete deployment billing --ignore-not-found=true >/dev/null 2>&1 || true

# Broken state: production credential stored in a ConfigMap and injected from it
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: credential-hygiene
data:
  app_mode: production
  log_level: info
  db_password: S3cr3t-Hunter2-9000
YAML

cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing
  namespace: credential-hygiene
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
        image: busybox:1.36
        command: ["/bin/sh","-c","sleep 86400"]
        env:
        - name: DB_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: db_password
YAML

kubectl -n "$NS" rollout status deployment/billing --timeout=120s >/dev/null 2>&1 || true

echo "Question 10 setup complete"
