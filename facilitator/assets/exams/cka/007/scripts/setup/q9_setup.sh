#!/bin/bash
set -euo pipefail
NS=cka-q09
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slow-api
  namespace: cka-q09
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
