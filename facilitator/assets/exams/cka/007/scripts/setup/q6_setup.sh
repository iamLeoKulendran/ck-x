#!/bin/bash
set -euo pipefail
NS=cka007-q06

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete daemonset packet-capture --ignore-not-found=true >/dev/null 2>&1 || true
kubectl label nodes --all q06.capture- >/dev/null 2>&1 || true
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: packet-capture
  namespace: cka007-q06
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
