#!/bin/bash
set -euo pipefail

NS="container-hardening"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Broken state: privileged root container sharing host PID namespace.
# Delete-then-apply guarantees a full reset of any candidate hardening.
kubectl -n "$NS" delete deployment sensor-agent --ignore-not-found=true >/dev/null 2>&1 || true
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sensor-agent
  namespace: container-hardening
  labels:
    app: sensor-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sensor-agent
  template:
    metadata:
      labels:
        app: sensor-agent
    spec:
      hostPID: true
      containers:
      - name: agent
        image: busybox:1.36
        command: ["/bin/sh","-c","sleep 86400"]
        securityContext:
          privileged: true
          runAsUser: 0
YAML

kubectl -n "$NS" rollout status deployment/sensor-agent --timeout=120s >/dev/null 2>&1 || true

echo "Question 6 setup complete"
