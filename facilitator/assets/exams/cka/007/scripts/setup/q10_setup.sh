#!/bin/bash
set -euo pipefail
NS=cka007-q10

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment catalog-web --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete service catalog-web --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-web
  namespace: cka007-q10
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog-web
  template:
    metadata:
      labels:
        app: catalog-web
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /readyz
            port: 80
          initialDelaySeconds: 1
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-web
  namespace: cka007-q10
spec:
  selector:
    app: catalog-web
  ports:
  - port: 80
    targetPort: 80
YAML
exit 0
