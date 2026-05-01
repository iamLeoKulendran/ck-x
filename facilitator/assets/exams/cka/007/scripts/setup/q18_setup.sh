#!/bin/bash
set -euo pipefail
NS=cka-q18
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pay-api
  namespace: cka-q18
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
