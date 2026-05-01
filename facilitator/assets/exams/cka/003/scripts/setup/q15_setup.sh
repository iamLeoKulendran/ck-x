#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q15
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$NS" pod-security.kubernetes.io/enforce- pod-security.kubernetes.io/audit- pod-security.kubernetes.io/warn- >/dev/null 2>&1 || true
exit 0
