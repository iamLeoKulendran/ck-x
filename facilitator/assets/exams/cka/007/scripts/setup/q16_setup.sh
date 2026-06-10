#!/bin/bash
set -euo pipefail
NS=cka007-q16

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment reserved-api --ignore-not-found=true >/dev/null 2>&1 || true

# Reset any previously applied q16 labels/taints before re-applying
kubectl label nodes --all q16.pool- >/dev/null 2>&1 || true
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

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
  namespace: cka007-q16
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
