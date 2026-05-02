#!/bin/bash
set -euo pipefail
NS="rev1-q14"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete deployment api-server --ignore-not-found=true
kubectl -n "$NS" delete service api-svc --ignore-not-found=true
sleep 2

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: rev1-q14
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: api
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: rev1-q14
spec:
  selector:
    app: api-server
  ports:
  - port: 80
    targetPort: 80
EOF

echo "Q14 setup complete"
