#!/bin/bash
set -euo pipefail
NS="rev1-q09"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete daemonset log-collector --ignore-not-found=true
sleep 2
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  namespace: rev1-q09
spec:
  selector:
    matchLabels:
      app: log-collector
  updateStrategy:
    type: OnDelete
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: log-collector
        image: nginx:1.27
EOF
echo "Q9 setup complete"
