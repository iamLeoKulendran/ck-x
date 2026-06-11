#!/bin/bash
set -euo pipefail

for NS in edge-zone internal-api corp-tools; do
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

# Reset: remove any candidate-created policies so the question starts open
kubectl -n edge-zone delete networkpolicy --all --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gateway-proxy
  namespace: edge-zone
  labels:
    app: gateway-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gateway-proxy
  template:
    metadata:
      labels:
        app: gateway-proxy
    spec:
      containers:
      - name: proxy
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api
  namespace: internal-api
  labels:
    app: orders-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orders-api
  template:
    metadata:
      labels:
        app: orders-api
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: orders-api-svc
  namespace: internal-api
spec:
  selector:
    app: orders-api
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy
  namespace: corp-tools
  labels:
    app: legacy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy
  template:
    metadata:
      labels:
        app: legacy
    spec:
      containers:
      - name: legacy
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: legacy-svc
  namespace: corp-tools
spec:
  selector:
    app: legacy
  ports:
  - port: 80
    targetPort: 80
YAML

kubectl -n edge-zone rollout status deployment/gateway-proxy --timeout=120s >/dev/null 2>&1 || true
kubectl -n internal-api rollout status deployment/orders-api --timeout=120s >/dev/null 2>&1 || true
kubectl -n corp-tools rollout status deployment/legacy --timeout=120s >/dev/null 2>&1 || true

echo "Question 1 setup complete"
