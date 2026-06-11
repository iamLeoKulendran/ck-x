#!/bin/bash
set -euo pipefail

NS="immutable-infra"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Broken state: container writes its data onto the writable root filesystem
kubectl -n "$NS" delete deployment report-writer --ignore-not-found=true >/dev/null 2>&1 || true
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-writer
  namespace: immutable-infra
  labels:
    app: report-writer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: report-writer
  template:
    metadata:
      labels:
        app: report-writer
    spec:
      containers:
      - name: writer
        image: busybox:1.36
        command: ["/bin/sh","-c","mkdir -p /data && while true; do date >> /data/report.log; sleep 5; done"]
YAML

kubectl -n "$NS" rollout status deployment/report-writer --timeout=120s >/dev/null 2>&1 || true

echo "Question 16 setup complete"
