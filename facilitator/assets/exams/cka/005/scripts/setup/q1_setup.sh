#!/bin/bash
set -euo pipefail
NS="rev1-q01"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete pod web-init db-backend --ignore-not-found=true
kubectl -n "$NS" delete service db-service --ignore-not-found=true
sleep 2
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: web-init
  namespace: rev1-q01
spec:
  initContainers:
  - name: wait-for-db
    image: busybox:1.36
    command: ["sh", "-c", "until nc -z db-service.rev1-q01.svc.cluster.local 5432; do echo waiting for db-service; sleep 2; done"]
  containers:
  - name: web
    image: nginx:1.27
    ports:
    - containerPort: 80
EOF
echo "Q1 setup complete"
