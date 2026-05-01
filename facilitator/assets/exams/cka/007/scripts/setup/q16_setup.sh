#!/bin/bash
set -euo pipefail
NS=cka-q16
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
NODE=$(kubectl get nodes --no-headers | awk '!/control-plane|master/ {print $1; exit}')
[ -z "$NODE" ] && NODE=$(kubectl get nodes --no-headers | awk '{print $1; exit}')
kubectl label node "$NODE" q16.pool=reserved --overwrite >/dev/null
kubectl taint node "$NODE" q16.pool=reserved:NoSchedule --overwrite >/dev/null
kubectl taint node "$NODE" q16.soft=reserved:PreferNoSchedule --overwrite >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reserved-api
  namespace: cka-q16
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reserved-api
  template:
    metadata:
      labels:
        app: reserved-api
    spec:
      nodeSelector:
        q16.pool: reserved
      containers:
      - name: api
        image: nginx:1.27
YAML
exit 0
