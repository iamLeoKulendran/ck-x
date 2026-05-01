#!/bin/bash
set -euo pipefail
NS=cka-q04
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Service
metadata:
  name: metrics-store-hl
  namespace: cka-q04
spec:
  clusterIP: None
  selector:
    app: metrics-store
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: metrics-store
  namespace: cka-q04
spec:
  serviceName: metrics-store-hl
  replicas: 2
  selector:
    matchLabels:
      app: metrics-store
  template:
    metadata:
      labels:
        app: metrics-store
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
        volumeMounts:
        - name: cache
          mountPath: /usr/share/nginx/html
      volumes:
      - name: cache
        emptyDir: {}
YAML
exit 0
