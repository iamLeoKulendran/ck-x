#!/bin/bash
set -euo pipefail

NS="restricted-apps"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Reset: strip PSA labels and candidate artifacts so the question starts unsolved
kubectl label namespace "$NS" pod-security.kubernetes.io/enforce- >/dev/null 2>&1 || true
kubectl label namespace "$NS" pod-security.kubernetes.io/enforce-version- >/dev/null 2>&1 || true
kubectl label namespace "$NS" pod-security.kubernetes.io/warn- >/dev/null 2>&1 || true
kubectl label namespace "$NS" pod-security.kubernetes.io/audit- >/dev/null 2>&1 || true
kubectl -n "$NS" delete pod intruder --ignore-not-found=true >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q8
rm -f /tmp/exam/q8/rejection.txt

# Plant the violating pod manifest the candidate must attempt to apply
cat > /tmp/exam/q8/bad-pod.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: intruder
  namespace: restricted-apps
spec:
  containers:
  - name: shell
    image: busybox:1.36
    command: ["/bin/sh","-c","sleep 3600"]
    securityContext:
      privileged: true
YAML

# Broken state: non-compliant workload running before the namespace is locked down
kubectl -n "$NS" delete deployment legacy-api --ignore-not-found=true >/dev/null 2>&1 || true
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-api
  namespace: restricted-apps
  labels:
    app: legacy-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy-api
  template:
    metadata:
      labels:
        app: legacy-api
    spec:
      containers:
      - name: api
        image: busybox:1.36
        command: ["/bin/sh","-c","sleep 86400"]
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true
YAML

kubectl -n "$NS" rollout status deployment/legacy-api --timeout=120s >/dev/null 2>&1 || true

echo "Question 8 setup complete"
