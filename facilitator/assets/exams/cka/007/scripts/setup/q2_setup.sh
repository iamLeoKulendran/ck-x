#!/bin/bash
set -euo pipefail
NS=cka-q02
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-web
  namespace: cka-q02
spec:
  replicas: 4
  selector:
    matchLabels:
      app: orders-web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 2
  template:
    metadata:
      labels:
        app: orders-web
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /not-ready
            port: 8080
          initialDelaySeconds: 1
          periodSeconds: 3
YAML
exit 0
