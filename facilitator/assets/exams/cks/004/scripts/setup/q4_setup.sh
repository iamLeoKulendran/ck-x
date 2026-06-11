#!/bin/bash
set -euo pipefail

NS="support-rbac"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$NS" create serviceaccount oncall-sa --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Misconfigured starting state: grants pods/exec create (too much) and is missing pods/log
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: oncall-role
  namespace: support-rbac
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec"]
  verbs: ["get", "list", "watch", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: oncall-binding
  namespace: support-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: oncall-role
subjects:
- kind: ServiceAccount
  name: oncall-sa
  namespace: support-rbac
YAML

echo "Question 4 setup complete"
