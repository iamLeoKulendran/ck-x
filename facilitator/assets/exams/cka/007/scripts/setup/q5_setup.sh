#!/bin/bash
set -euo pipefail
NS=cka-q05
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-log-agent
  namespace: cka-q05
spec:
  selector:
    matchLabels:
      app: node-log-agent
  template:
    metadata:
      labels:
        app: node-log-agent
    spec:
      containers:
      - name: agent
        image: busybox:1.36
        command: ["sh","-c","sleep 3600"]
YAML
exit 0
