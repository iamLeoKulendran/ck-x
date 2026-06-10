#!/bin/bash
set -euo pipefail
NS=cka007-q14

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment reporting-api --ignore-not-found=true >/dev/null 2>&1 || true
kubectl label nodes --all q14.disk- >/dev/null 2>&1 || true
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reporting-api
  namespace: cka007-q14
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
