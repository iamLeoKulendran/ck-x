#!/bin/bash
set -euo pipefail

NS="checkout"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset: recreate the deployment and service in the broken state
kubectl -n "$NS" delete deployment checkout-api --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete service checkout-svc --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-api
  namespace: checkout
  labels:
    app: checkout-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: checkout-api
  template:
    metadata:
      labels:
        app: checkout-api
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: checkout-svc
  namespace: checkout
spec:
  selector:
    app: checkout-api
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storefront-client
  namespace: checkout
  labels:
    app: storefront-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storefront-client
  template:
    metadata:
      labels:
        app: storefront-client
    spec:
      containers:
      - name: client
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
YAML

# checkout-api is intentionally stuck in CreateContainerConfigError; only wait for the client
kubectl -n "$NS" rollout status deployment/storefront-client --timeout=120s >/dev/null 2>&1 || true

echo "Question 8 setup complete"
