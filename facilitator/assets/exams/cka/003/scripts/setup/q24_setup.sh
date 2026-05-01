#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q24
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete rolebinding q24-token-rotator >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q24-token-rotator >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa token-rotator >/dev/null 2>&1 || true
kubectl -n "$NS" delete secret app-token other-token >/dev/null 2>&1 || true
kubectl -n "$NS" create sa token-rotator
kubectl -n "$NS" create secret generic app-token --from-literal=token=old
kubectl -n "$NS" create secret generic other-token --from-literal=token=other
exit 0
