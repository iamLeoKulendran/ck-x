#!/bin/bash
set -euo pipefail
NS=cka-q11
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
kubectl create configmap app-settings -n "$NS" --from-literal=APP_MODE=production >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-consumer
  namespace: cka-q11
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
