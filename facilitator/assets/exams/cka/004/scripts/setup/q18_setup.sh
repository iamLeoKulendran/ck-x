#!/bin/bash
set -euo pipefail
NS=cka-q18
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete deployment q18-web -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
