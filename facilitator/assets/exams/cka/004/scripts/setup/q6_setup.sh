#!/bin/bash
set -euo pipefail
NS=cka-q06
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q6-data
kubectl delete deployment q6-safari -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete pvc q6-safari-pvc -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete pv q6-safari-pv --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
