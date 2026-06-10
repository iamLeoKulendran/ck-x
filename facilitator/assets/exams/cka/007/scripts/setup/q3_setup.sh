#!/bin/bash
set -euo pipefail
NS=cka007-q03

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

# P2.3: keep hard delete — StatefulSet stable identities need a clean namespace
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ledger-db
  namespace: cka007-q03
spec:
  serviceName: wrong-ledger-service
  replicas: 2
  selector:
    matchLabels:
      app: ledger-db
  template:
    metadata:
      labels:
        app: ledger-db
    spec:
      containers:
      - name: db
        image: nginx:1.27
        ports:
        - containerPort: 80
YAML
exit 0
