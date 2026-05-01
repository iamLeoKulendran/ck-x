#!/bin/bash
set -euo pipefail
NS=cka-q24
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete pod q24-important -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete priorityclass q24-high-priority --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
