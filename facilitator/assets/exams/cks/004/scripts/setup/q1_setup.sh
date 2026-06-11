#!/bin/bash
set -euo pipefail

REG="registry.localhost:5000/ckx/nginx:v1.25"

kubectl create namespace frontend-zone --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Trusted and untrusted client namespaces
kubectl create namespace trusted-clients --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label namespace trusted-clients tier=trusted --overwrite >/dev/null
kubectl create namespace untrusted-clients --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label namespace untrusted-clients tier- >/dev/null 2>&1 || true

# Reset: remove any candidate policies so the namespace starts open
kubectl -n frontend-zone delete networkpolicy --all --ignore-not-found=true >/dev/null 2>&1 || true

cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storefront
  namespace: frontend-zone
  labels:
    app: storefront
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storefront
  template:
    metadata:
      labels:
        app: storefront
    spec:
      containers:
      - name: web
        image: ${REG}
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: storefront-svc
  namespace: frontend-zone
spec:
  selector:
    app: storefront
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: trusted-clients
  labels:
    app: client
spec:
  containers:
  - name: client
    image: registry.localhost:5000/ckx/alpine:3.20
    command: ["sleep", "infinity"]
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: untrusted-clients
  labels:
    app: client
spec:
  containers:
  - name: client
    image: registry.localhost:5000/ckx/alpine:3.20
    command: ["sleep", "infinity"]
YAML

kubectl -n frontend-zone rollout status deployment/storefront --timeout=120s >/dev/null 2>&1 || true
kubectl -n trusted-clients wait --for=condition=Ready pod/client --timeout=120s >/dev/null 2>&1 || true
kubectl -n untrusted-clients wait --for=condition=Ready pod/client --timeout=120s >/dev/null 2>&1 || true

echo "Question 1 setup complete"
