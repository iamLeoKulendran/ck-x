#!/bin/bash
set -euo pipefail
NS=cka-q20
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete service q20-api-svc -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete deployment q20-api -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q20-api
  namespace: $NS
spec:
  replicas: 2
  selector:
    matchLabels:
      app: q20-api
  template:
    metadata:
      labels:
        app: q20-api
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF
exit 0
