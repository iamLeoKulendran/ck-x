#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q3
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete rolebinding q3-read-deployments >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q3-deployment-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa deploy-reader >/dev/null 2>&1 || true
kubectl -n "$NS" create sa deploy-reader
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q3-deployment-reader
  namespace: $NS
rules:
- apiGroups: [""]
  resources: ["deployments"]
  verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q3-read-deployments
  namespace: $NS
subjects:
- kind: ServiceAccount
  name: deploy-reader
  namespace: $NS
roleRef:
  kind: Role
  name: q3-deployment-reader
  apiGroup: rbac.authorization.k8s.io
EOF
exit 0
