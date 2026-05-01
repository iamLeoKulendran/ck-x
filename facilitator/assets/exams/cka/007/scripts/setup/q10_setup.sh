#!/bin/bash
set -euo pipefail
NS=cka-q10
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-web
  namespace: cka-q10
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog-web
  template:
    metadata:
      labels:
        app: catalog-web
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /readyz
            port: 80
          initialDelaySeconds: 1
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-web
  namespace: cka-q10
spec:
  selector:
    app: catalog-web
  ports:
  - port: 80
    targetPort: 80
YAML
exit 0
