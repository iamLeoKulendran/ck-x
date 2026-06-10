#!/bin/bash
set -euo pipefail
NS=cka007-q19

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

# P2.3: keep hard delete — ResourceQuota + pods must be fully reset to reproduce quota exhaustion
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: cka007-q19
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1"
    limits.memory: "1Gi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quota-api
  namespace: cka007-q19
spec:
  replicas: 2
  selector:
    matchLabels:
      app: quota-api
  template:
    metadata:
      labels:
        app: quota-api
    spec:
      containers:
      - name: api
        image: nginx:1.27
        resources:
          requests:
            cpu: "400m"
            memory: "400Mi"
          limits:
            cpu: "800m"
            memory: "800Mi"
YAML
exit 0
