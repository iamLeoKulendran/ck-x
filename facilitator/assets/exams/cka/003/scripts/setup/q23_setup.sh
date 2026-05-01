#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q23
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete pod q23-db-client >/dev/null 2>&1 || true
kubectl -n "$NS" delete secret q23-db-secret >/dev/null 2>&1 || true
exit 0
