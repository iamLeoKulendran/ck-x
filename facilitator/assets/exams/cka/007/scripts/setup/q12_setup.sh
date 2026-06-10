#!/bin/bash
set -euo pipefail
NS=cka007-q12

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment payment-worker --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete secret db-credentials --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create secret generic db-credentials -n "$NS" --from-literal=password=s3cr3t >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-worker
  namespace: cka007-q12
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-worker
  template:
    metadata:
      labels:
        app: payment-worker
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh","-c","while true; do echo running; sleep 30; done"]
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: pwd
YAML
exit 0
