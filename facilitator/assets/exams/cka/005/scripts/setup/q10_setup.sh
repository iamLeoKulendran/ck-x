#!/bin/bash
set -euo pipefail
NS="rev1-q10"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete networkpolicy api-policy --ignore-not-found=true
kubectl -n "$NS" delete pod frontend-pod api-pod db-pod --ignore-not-found=true
sleep 1
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod
  namespace: rev1-q10
  labels:
    app: frontend
spec:
  containers:
  - name: app
    image: nginx:1.27
---
apiVersion: v1
kind: Pod
metadata:
  name: api-pod
  namespace: rev1-q10
  labels:
    app: api
spec:
  containers:
  - name: app
    image: nginx:1.27
---
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
  namespace: rev1-q10
  labels:
    app: db
spec:
  containers:
  - name: app
    image: nginx:1.27
EOF
echo "Q10 setup complete"
