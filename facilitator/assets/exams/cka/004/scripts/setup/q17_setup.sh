#!/bin/bash
set -euo pipefail
NS=cka-q17
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete pod q17-resource-check -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
