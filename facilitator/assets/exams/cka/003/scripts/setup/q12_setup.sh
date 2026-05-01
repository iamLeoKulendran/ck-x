#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q12
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete clusterrolebinding q12-impersonate-limited-user >/dev/null 2>&1 || true
kubectl delete clusterrole q12-impersonate-limited-user >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa impersonator >/dev/null 2>&1 || true
kubectl -n "$NS" create sa impersonator
exit 0
