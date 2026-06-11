#!/bin/bash
set -euo pipefail

NS="registry-guard"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label namespace "$NS" registry-policy=enforced --overwrite >/dev/null

# Reset candidate policy objects so nothing is enforced at the start
kubectl delete validatingadmissionpolicybinding trusted-registry-only-binding --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete validatingadmissionpolicy trusted-registry-only --ignore-not-found=true >/dev/null 2>&1 || true

# Remove any leftover test pods from prior attempts
kubectl -n "$NS" delete pod public-pod compliant-pod --ignore-not-found=true >/dev/null 2>&1 || true

echo "Question 5 setup complete"
