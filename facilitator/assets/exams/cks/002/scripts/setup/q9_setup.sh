#!/bin/bash
set -euo pipefail

NS="admission-control"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$NS" env=prod --overwrite >/dev/null

# Reset: remove candidate-created policy objects and stray test deployments
kubectl delete validatingadmissionpolicybinding deny-latest-tag-binding --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete validatingadmissionpolicy deny-latest-tag --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete deployment bad-latest ok-pinned ckx-vap-probe-bad ckx-vap-probe-ok --ignore-not-found=true >/dev/null 2>&1 || true

echo "Question 9 setup complete"
