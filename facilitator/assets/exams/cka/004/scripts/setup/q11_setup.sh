#!/bin/bash
set -euo pipefail
NS=cka-q11
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create sa node-reader -n "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete clusterrolebinding q11-node-reader --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete clusterrole q11-node-reader --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
