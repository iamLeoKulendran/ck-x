#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q16
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete networkpolicy q16-db-ingress >/dev/null 2>&1 || true
kubectl -n "$NS" delete pod q16-db q16-frontend >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q16-db
  namespace: $NS
  labels:
    role: db
spec:
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.9
---
apiVersion: v1
kind: Pod
metadata:
  name: q16-frontend
  namespace: $NS
  labels:
    role: frontend
spec:
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.9
EOF
exit 0
