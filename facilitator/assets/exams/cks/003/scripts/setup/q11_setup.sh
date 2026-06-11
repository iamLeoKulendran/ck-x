#!/bin/bash
set -euo pipefail

NS="release-engineering"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Reset: remove the candidate-deployed workload and any produced artifacts
kubectl -n "$NS" delete deployment webhook-gw --ignore-not-found=true >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q11
rm -f /tmp/exam/q11/trivy-report.txt /tmp/exam/q11/kubesec-report.json /tmp/exam/q11/webhook-deploy-fixed.yaml

cat > /tmp/exam/q11/webhook-deploy.yaml <<'MANIFEST'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webhook-gw
  namespace: release-engineering
  labels:
    app: webhook-gw
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webhook-gw
  template:
    metadata:
      labels:
        app: webhook-gw
    spec:
      hostPID: true
      containers:
      - name: gw
        image: busybox:latest
        command: ["sh", "-c", "sleep 86400"]
        securityContext:
          privileged: true
MANIFEST

echo "Question 11 setup complete"
