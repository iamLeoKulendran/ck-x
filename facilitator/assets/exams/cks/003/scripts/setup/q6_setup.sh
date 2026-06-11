#!/bin/bash
set -euo pipefail

NS="node-ops"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset: recreate the deployment in its overprivileged broken state
kubectl -n "$NS" delete deployment host-inspector --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: host-inspector
  namespace: node-ops
  labels:
    app: host-inspector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: host-inspector
  template:
    metadata:
      labels:
        app: host-inspector
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: inspector
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        volumeMounts:
        - name: host-root
          mountPath: /host
          readOnly: true
      volumes:
      - name: host-root
        hostPath:
          path: /
YAML

kubectl -n "$NS" rollout status deployment/host-inspector --timeout=120s >/dev/null 2>&1 || true

echo "Question 6 setup complete"
