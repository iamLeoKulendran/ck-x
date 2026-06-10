#!/bin/bash
set -euo pipefail
NS=cka007-q02

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment orders-web --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-web
  namespace: cka007-q02
spec:
  replicas: 4
  selector:
    matchLabels:
      app: orders-web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 2
  template:
    metadata:
      labels:
        app: orders-web
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /not-ready
            port: 8080
          initialDelaySeconds: 1
          periodSeconds: 3
YAML
exit 0
