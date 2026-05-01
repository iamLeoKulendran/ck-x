#!/bin/bash
set -euo pipefail
NS=cka-q15
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete pod q15-configured -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create configmap app-settings -n "$NS" --from-literal=APP_MODE=prod --from-literal=LOG_LEVEL=info --dry-run=client -o yaml | kubectl apply -f -
exit 0
