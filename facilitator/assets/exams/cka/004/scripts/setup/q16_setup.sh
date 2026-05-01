#!/bin/bash
set -euo pipefail
NS=cka-q16
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete pod q16-db-client -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete secret q16-db-secret -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
