#!/bin/bash
set -euo pipefail
NS=cka-q01
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-api
  namespace: cka-q01
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: frontend-api
    spec:
      containers:
      - name: frontend
        image: nginx:1.27-broken
        ports:
        - containerPort: 80
YAML
kubectl rollout pause deploy/frontend-api -n "$NS" >/dev/null
exit 0
