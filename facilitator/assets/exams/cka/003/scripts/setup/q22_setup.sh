#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q22
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$NS" pod-security.kubernetes.io/enforce=restricted --overwrite >/dev/null
kubectl -n "$NS" delete deployment q22-restricted-nginx >/dev/null 2>&1 || true
exit 0
