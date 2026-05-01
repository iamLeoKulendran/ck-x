#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q17
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete deployment q17-private-app >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa image-puller >/dev/null 2>&1 || true
kubectl -n "$NS" delete secret q17-regcred >/dev/null 2>&1 || true
kubectl -n "$NS" create secret docker-registry q17-regcred --docker-server=registry.example.invalid --docker-username=user --docker-password=pass --docker-email=user@example.invalid
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q17-private-app
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q17-private-app
  template:
    metadata:
      labels:
        app: q17-private-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
EOF
exit 0
