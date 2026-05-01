#!/bin/bash
set -euo pipefail
NS=cka-q08
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete service q8-web-svc -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete deployment q8-web -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q8-web
  namespace: $NS
spec:
  replicas: 2
  selector:
    matchLabels:
      app: q8-web
  template:
    metadata:
      labels:
        app: q8-web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: q8-web-svc
  namespace: $NS
spec:
  selector:
    app: wrong-selector
  ports:
  - port: 80
    targetPort: 80
EOF
exit 0
