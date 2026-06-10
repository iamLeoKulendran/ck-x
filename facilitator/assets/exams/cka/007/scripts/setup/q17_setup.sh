#!/bin/bash
set -euo pipefail
NS=cka007-q17

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment ha-web --ignore-not-found=true >/dev/null 2>&1 || true

for n in $(kubectl get nodes -o name | cut -d/ -f2); do kubectl label node "$n" q17.rack=rack-a --overwrite >/dev/null; done
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-web
  namespace: cka007-q17
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ha-web
  template:
    metadata:
      labels:
        app: ha-web
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: ha-web
            topologyKey: q17.rack
      containers:
      - name: web
        image: nginx:1.27
YAML
exit 0
