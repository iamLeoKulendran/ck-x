#!/bin/bash
set -euo pipefail

NS="audit-team"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$NS" create serviceaccount report-sa --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# A configmap so list has something to return
kubectl -n "$NS" create configmap app-config --from-literal=mode=prod \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Over-permissive starting state: wildcard verbs on wildcard resources
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: report-role
  namespace: audit-team
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: report-sa-binding
  namespace: audit-team
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: report-role
subjects:
- kind: ServiceAccount
  name: report-sa
  namespace: audit-team
YAML

echo "Question 3 setup complete"
