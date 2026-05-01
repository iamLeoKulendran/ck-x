#!/bin/bash
set -euo pipefail
NS=cka-q17
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
for n in $(kubectl get nodes -o name | cut -d/ -f2); do kubectl label node "$n" q17.rack=rack-a --overwrite >/dev/null; done
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-web
  namespace: cka-q17
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
