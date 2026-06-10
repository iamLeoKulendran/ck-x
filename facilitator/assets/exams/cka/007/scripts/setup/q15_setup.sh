#!/bin/bash
set -euo pipefail
NS=cka007-q15

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment analytics-api --ignore-not-found=true >/dev/null 2>&1 || true
kubectl label nodes --all q15.accelerator- >/dev/null 2>&1 || true
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-api
  namespace: cka007-q15
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
