#!/bin/bash
set -euo pipefail
NS="rev1-q17"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete deployment dual-svc-app --ignore-not-found=true
kubectl -n "$NS" delete service dual-svc --ignore-not-found=true
echo "Q17 setup complete"
