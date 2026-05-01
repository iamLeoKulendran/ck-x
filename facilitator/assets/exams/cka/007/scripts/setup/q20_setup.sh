#!/bin/bash
set -euo pipefail
NS=cka-q20
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl delete priorityclass business-critical --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-api
  namespace: cka-q20
spec:
  replicas: 1
  selector:
    matchLabels:
      app: critical-api
  template:
    metadata:
      labels:
        app: critical-api
    spec:
      priorityClassName: business-critical
      containers:
      - name: api
        image: nginx:1.27
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
YAML
exit 0
