#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q20
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete sa troubleshoot-sa >/dev/null 2>&1 || true
kubectl -n "$NS" create sa troubleshoot-sa
mkdir -p /tmp/exam/q20
rm -f /tmp/exam/q20/inspect_rbac.sh
exit 0
