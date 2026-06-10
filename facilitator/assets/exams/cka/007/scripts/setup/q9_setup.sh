#!/bin/bash
set -euo pipefail
NS=cka007-q09

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment slow-api --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slow-api
  namespace: cka007-q09
spec:
  replicas: 1
  selector:
    matchLabels:
      app: slow-api
  template:
    metadata:
      labels:
        app: slow-api
    spec:
      containers:
      - name: api
        image: busybox:1.36
        command: ["sh","-c","rm -f /tmp/healthy; sleep 25; touch /tmp/healthy; sleep 3600"]
        livenessProbe:
          exec:
            command: ["cat","/tmp/healthy"]
          initialDelaySeconds: 1
          periodSeconds: 1
          failureThreshold: 3
YAML
exit 0
