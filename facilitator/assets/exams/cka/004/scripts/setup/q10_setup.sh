#!/bin/bash
set -euo pipefail
NS=cka-q10
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete rolebinding processor -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete role processor -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete serviceaccount processor -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
