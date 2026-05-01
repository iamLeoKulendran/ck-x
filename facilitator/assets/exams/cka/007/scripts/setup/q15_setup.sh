#!/bin/bash
set -euo pipefail
NS=cka-q15
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
kubectl label nodes --all q15.accelerator- >/dev/null 2>&1 || true
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-api
  namespace: cka-q15
spec:
  replicas: 2
  selector:
    matchLabels:
      app: analytics-api
  template:
    metadata:
      labels:
        app: analytics-api
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: q15.accelerator
                operator: In
                values: ["gpu"]
      containers:
      - name: api
        image: nginx:1.27
YAML
exit 0
