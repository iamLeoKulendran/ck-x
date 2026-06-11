#!/bin/bash
set -euo pipefail

NS="notify"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

mkdir -p /tmp/exam/q16
rm -f /tmp/exam/q16/leaked-token.txt

# Reset: restore the original (leaked) secret value and the leaky startup command
kubectl -n "$NS" delete deployment notify-bot --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: notify-token
  namespace: notify
type: Opaque
stringData:
  token: ntfy_8d31f7c2a99e
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notify-bot
  namespace: notify
  labels:
    app: notify-bot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notify-bot
  template:
    metadata:
      labels:
        app: notify-bot
    spec:
      containers:
      - name: bot
        image: busybox:1.36
        command: ["sh", "-c", "echo \"startup: notifier using token=$NOTIFY_TOKEN\"; while true; do sleep 3600; done"]
        env:
        - name: NOTIFY_TOKEN
          valueFrom:
            secretKeyRef:
              name: notify-token
              key: token
YAML

kubectl -n "$NS" rollout status deployment/notify-bot --timeout=120s >/dev/null 2>&1 || true

echo "Question 16 setup complete"
