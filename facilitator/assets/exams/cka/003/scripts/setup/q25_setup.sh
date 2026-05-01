#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q25
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q25
rm -f /tmp/exam/q25/tls.crt /tmp/exam/q25/tls.key
kubectl -n "$NS" delete secret q25-tls >/dev/null 2>&1 || true
exit 0
