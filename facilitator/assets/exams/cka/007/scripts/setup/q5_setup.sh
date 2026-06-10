#!/bin/bash
set -euo pipefail
NS=cka007-q05

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete daemonset node-log-agent --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-log-agent
  namespace: cka007-q05
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
