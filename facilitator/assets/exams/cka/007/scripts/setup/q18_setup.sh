#!/bin/bash
set -euo pipefail
NS=cka007-q18

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment pay-api --ignore-not-found=true >/dev/null 2>&1 || true
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pay-api
  namespace: cka007-q18
spec:
  replicas: 4
  selector:
    matchLabels:
      app: pay-api
  template:
    metadata:
      labels:
        app: pay-api
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: wrong-pay-api
      containers:
      - name: api
        image: nginx:1.27
YAML
exit 0
