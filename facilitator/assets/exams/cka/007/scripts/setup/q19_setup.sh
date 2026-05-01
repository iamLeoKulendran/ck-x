#!/bin/bash
set -euo pipefail
NS=cka-q19
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: cka-q19
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1"
    limits.memory: "1Gi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quota-api
  namespace: cka-q19
spec:
  replicas: 2
  selector:
    matchLabels:
      app: quota-api
  template:
    metadata:
      labels:
        app: quota-api
    spec:
      containers:
      - name: api
        image: nginx:1.27
        resources:
          requests:
            cpu: "400m"
            memory: "400Mi"
          limits:
            cpu: "800m"
            memory: "800Mi"
YAML
exit 0
