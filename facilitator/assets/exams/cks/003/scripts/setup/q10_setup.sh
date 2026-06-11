#!/bin/bash
set -euo pipefail

NS="storage-guard"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label namespace "$NS" volume-policy=restricted --overwrite >/dev/null

# Reset: remove candidate-created policy objects and pods
kubectl delete validatingadmissionpolicybinding deny-hostpath-binding --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete validatingadmissionpolicy deny-hostpath --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete pod safe-cache --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete pod ckx-q10-probe --ignore-not-found=true >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q10
rm -f /tmp/exam/q10/rejected.txt

echo "Question 10 setup complete"
