#!/bin/bash
set -euo pipefail
NS=cka-q13
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: pinned-cache
  namespace: cka-q13
  labels:
    app: pinned-cache
spec:
  nodeName: ghost-node
  containers:
  - name: nginx
    image: nginx:1.27
YAML
exit 0
