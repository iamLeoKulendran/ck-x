#!/bin/bash
set -euo pipefail
NS=cka-q19
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete pod q19-broken -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q19-broken
  namespace: $NS
spec:
  containers:
  - name: nginx
    image: nginx:badtag-cka
EOF
exit 0
