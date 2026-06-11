#!/bin/bash
set -euo pipefail

NS="supply-scan"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment scanner-api --ignore-not-found=true >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q12
rm -f /tmp/exam/q12/findings.txt

# Plant an insecure third-party manifest for the candidate to scan with trivy config
cat > /tmp/exam/q12/workload.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanner-api
  namespace: supply-scan
  labels:
    app: scanner-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scanner-api
  template:
    metadata:
      labels:
        app: scanner-api
    spec:
      containers:
      - name: api
        image: nginx:1.25
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true
          runAsUser: 0
        ports:
        - containerPort: 80
YAML

echo "Question 12 setup complete"
