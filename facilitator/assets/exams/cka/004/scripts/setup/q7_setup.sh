#!/bin/bash
set -euo pipefail
NS=cka-q07
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete deployment q7-broken-web -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create deployment q7-broken-web -n "$NS" --image=nginx:1.25 --replicas=2 >/dev/null 2>&1 || true
kubectl rollout status deployment/q7-broken-web -n "$NS" --timeout=60s >/dev/null 2>&1 || true
kubectl set image deployment/q7-broken-web nginx=nginx:does-not-exist-q7 -n "$NS" >/dev/null 2>&1 || true
exit 0
