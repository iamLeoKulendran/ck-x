#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q13
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete rolebinding q13-app-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q13-app-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa app-reader >/dev/null 2>&1 || true
kubectl -n "$NS" create sa app-reader
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q13-app-reader
  namespace: $NS
rules:
- apiGroups: [""]
  resources: ["configmaps","secrets"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q13-app-reader
  namespace: $NS
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: $NS
roleRef:
  kind: Role
  name: q13-app-reader
  apiGroup: rbac.authorization.k8s.io
EOF
exit 0
