#!/bin/bash
set -euo pipefail

NS="syscall-guard"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Broken state: pod runs with seccomp explicitly Unconfined
kubectl -n "$NS" delete deployment event-logger --ignore-not-found=true >/dev/null 2>&1 || true
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-logger
  namespace: syscall-guard
  labels:
    app: event-logger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: event-logger
  template:
    metadata:
      labels:
        app: event-logger
    spec:
      securityContext:
        seccompProfile:
          type: Unconfined
      containers:
      - name: logger
        image: busybox:1.36
        command: ["/bin/sh","-c","sleep 86400"]
YAML

kubectl -n "$NS" rollout status deployment/event-logger --timeout=120s >/dev/null 2>&1 || true

echo "Question 7 setup complete"
