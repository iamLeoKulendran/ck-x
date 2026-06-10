#!/bin/bash
set -euo pipefail
NS=cka007-q01

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment frontend-api --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-api
  namespace: cka007-q01
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: frontend-api
    spec:
      containers:
      - name: frontend
        image: nginx:1.27-broken
        ports:
        - containerPort: 80
YAML
kubectl rollout pause deploy/frontend-api -n "$NS" >/dev/null
exit 0
