#!/bin/bash
set -euo pipefail
NS=cka-q09
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete networkpolicy q9-egress-lockdown -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q9-backend
  namespace: $NS
  labels:
    app: backend
spec:
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.9
---
apiVersion: v1
kind: Pod
metadata:
  name: q9-db
  namespace: $NS
  labels:
    app: db
spec:
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.9
EOF
exit 0
