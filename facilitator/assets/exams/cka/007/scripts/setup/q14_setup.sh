#!/bin/bash
set -euo pipefail
NS=cka-q14
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
kubectl label nodes --all q14.disk- >/dev/null 2>&1 || true
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reporting-api
  namespace: cka-q14
spec:
  replicas: 2
  selector:
    matchLabels:
      app: reporting-api
  template:
    metadata:
      labels:
        app: reporting-api
    spec:
      nodeSelector:
        q14.disk: ssd
      containers:
      - name: api
        image: nginx:1.27
YAML
exit 0
