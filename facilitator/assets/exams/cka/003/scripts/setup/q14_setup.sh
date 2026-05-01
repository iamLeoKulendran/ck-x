#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q14
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete pod q14-insecure-pod q14-secure-pod >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q14-insecure-pod
  namespace: $NS
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    securityContext:
      privileged: true
      allowPrivilegeEscalation: true
EOF
exit 0
