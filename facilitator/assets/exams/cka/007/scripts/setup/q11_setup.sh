#!/bin/bash
set -euo pipefail
NS=cka007-q11

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment config-consumer --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete configmap app-settings --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create configmap app-settings -n "$NS" --from-literal=APP_MODE=production >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-consumer
  namespace: cka007-q11
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-consumer
  template:
    metadata:
      labels:
        app: config-consumer
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh","-c","while true; do echo $APP_MODE; sleep 30; done"]
        env:
        - name: APP_MODE
          valueFrom:
            configMapKeyRef:
              name: app-settings
              key: app_mode
YAML
exit 0
