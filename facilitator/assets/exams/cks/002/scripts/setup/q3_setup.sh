#!/bin/bash
set -euo pipefail

NS="ci-pipeline"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" create serviceaccount build-bot --dry-run=client -o yaml | kubectl apply -f -

# Reset: remove candidate-created least-privilege objects
kubectl -n "$NS" delete role build-bot-role --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete rolebinding build-bot-binding --ignore-not-found=true >/dev/null 2>&1 || true

# Broken state: build-bot has full cluster-admin
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: build-bot-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: build-bot
  namespace: ci-pipeline
YAML

echo "Question 3 setup complete"
