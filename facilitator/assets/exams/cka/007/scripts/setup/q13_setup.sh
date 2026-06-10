#!/bin/bash
set -euo pipefail
NS=cka007-q13

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete pod pinned-cache --ignore-not-found=true --wait=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: pinned-cache
  namespace: cka007-q13
  labels:
    app: pinned-cache
spec:
  nodeName: ghost-node
  containers:
  - name: nginx
    image: nginx:1.27
YAML
exit 0
