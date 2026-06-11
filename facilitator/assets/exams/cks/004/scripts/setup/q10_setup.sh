#!/bin/bash
set -euo pipefail

REG_A="registry.localhost:5000/ckx/alpine:3.20"
REG_N="registry.localhost:5000/ckx/nginx:v1.25"

kubectl create namespace txn-mesh --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl create namespace txn-ledger --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label namespace txn-ledger tier=ledger --overwrite >/dev/null

kubectl create namespace txn-public --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label namespace txn-public tier- >/dev/null 2>&1 || true

# Reset: open egress at the start
kubectl -n txn-mesh delete networkpolicy --all --ignore-not-found=true >/dev/null 2>&1 || true

cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: processor
  namespace: txn-mesh
  labels:
    app: processor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: processor
  template:
    metadata:
      labels:
        app: processor
    spec:
      containers:
      - name: processor
        image: ${REG_A}
        command: ["sleep", "infinity"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger
  namespace: txn-ledger
  labels:
    app: ledger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ledger
  template:
    metadata:
      labels:
        app: ledger
    spec:
      containers:
      - name: ledger
        image: ${REG_N}
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: ledger-svc
  namespace: txn-ledger
spec:
  selector:
    app: ledger
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger
  namespace: txn-public
  labels:
    app: ledger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ledger
  template:
    metadata:
      labels:
        app: ledger
    spec:
      containers:
      - name: ledger
        image: ${REG_N}
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: ledger-svc
  namespace: txn-public
spec:
  selector:
    app: ledger
  ports:
  - port: 80
    targetPort: 80
YAML

kubectl -n txn-mesh rollout status deployment/processor --timeout=120s >/dev/null 2>&1 || true
kubectl -n txn-ledger rollout status deployment/ledger --timeout=120s >/dev/null 2>&1 || true
kubectl -n txn-public rollout status deployment/ledger --timeout=120s >/dev/null 2>&1 || true

echo "Question 10 setup complete"
