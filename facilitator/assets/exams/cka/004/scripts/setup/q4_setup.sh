#!/bin/bash
set -euo pipefail
NS=cka-q04
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete pod waiting-client dependency-server -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: service-check
  namespace: $NS
spec:
  selector:
    app: dependency
  ports:
  - port: 80
    targetPort: 80
EOF
exit 0
