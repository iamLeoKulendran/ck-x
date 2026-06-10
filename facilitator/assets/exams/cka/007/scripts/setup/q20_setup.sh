#!/bin/bash
set -euo pipefail
NS=cka007-q20

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment critical-api --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete priorityclass business-critical --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-api
  namespace: cka007-q20
spec:
  replicas: 1
  selector:
    matchLabels:
      app: critical-api
  template:
    metadata:
      labels:
        app: critical-api
    spec:
      priorityClassName: business-critical
      containers:
      - name: api
        image: nginx:1.27
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
YAML
exit 0
