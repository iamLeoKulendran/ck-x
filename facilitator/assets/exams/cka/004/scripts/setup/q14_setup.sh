#!/bin/bash
set -euo pipefail
NS=cka-q14
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete cronjob q14-cleanup -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
