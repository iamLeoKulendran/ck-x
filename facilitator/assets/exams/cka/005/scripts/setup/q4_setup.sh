#!/bin/bash
set -euo pipefail
NS="rev1-q04"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete deployment config-loader --ignore-not-found=true
kubectl -n "$NS" delete configmap app-config --ignore-not-found=true
sleep 1
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: rev1-q04
data:
  app.conf: |
    server_name=myapp
    log_level=info
    max_connections=100
EOF
echo "Q4 setup complete"
