#!/bin/bash
set -euo pipefail
NS=cka-q03
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ledger-db
  namespace: cka-q03
spec:
  serviceName: wrong-ledger-service
  replicas: 2
  selector:
    matchLabels:
      app: ledger-db
  template:
    metadata:
      labels:
        app: ledger-db
    spec:
      containers:
      - name: db
        image: nginx:1.27
        ports:
        - containerPort: 80
YAML
exit 0
