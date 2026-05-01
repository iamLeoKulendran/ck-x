#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q18
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete pod q18-token-pod >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q18-token-pod
  namespace: $NS
spec:
  automountServiceAccountToken: true
  containers:
  - name: nginx
    image: nginx:1.25
EOF
exit 0
