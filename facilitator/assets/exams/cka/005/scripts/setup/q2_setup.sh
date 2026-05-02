#!/bin/bash
set -euo pipefail
NS="rev1-q02"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete deployment frontend --ignore-not-found=true
kubectl -n "$NS" delete service frontend-svc --ignore-not-found=true
sleep 2
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: rev1-q02
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: app
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: rev1-q02
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
EOF
echo "Q2 setup complete"
