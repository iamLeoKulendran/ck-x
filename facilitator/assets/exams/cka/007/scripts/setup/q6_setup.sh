#!/bin/bash
set -euo pipefail
NS=cka-q06
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
kubectl label nodes --all q06.capture- >/dev/null 2>&1 || true
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: packet-capture
  namespace: cka-q06
spec:
  selector:
    matchLabels:
      app: packet-capture
  template:
    metadata:
      labels:
        app: packet-capture
    spec:
      nodeSelector:
        q06.capture: "true"
      containers:
      - name: capture
        image: busybox:1.36
        command: ["sh","-c","sleep 3600"]
YAML
exit 0
