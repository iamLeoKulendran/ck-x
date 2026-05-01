#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q7
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete deployment q7-api >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa app-runner >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q7-api
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q7-api
  template:
    metadata:
      labels:
        app: q7-api
    spec:
      serviceAccountName: default
      automountServiceAccountToken: true
      containers:
      - name: nginx
        image: nginx:1.25
EOF
exit 0
