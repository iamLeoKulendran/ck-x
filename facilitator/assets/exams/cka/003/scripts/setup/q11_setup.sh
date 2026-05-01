#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q11
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete rolebinding q11-read-pods >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q11-pod-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa reader >/dev/null 2>&1 || true
kubectl -n "$NS" create sa reader
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q11-pod-reader
  namespace: $NS
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q11-read-pods
  namespace: $NS
subjects:
- kind: ServiceAccount
  name: reader
  namespace: $NS
roleRef:
  kind: Role
  name: q11-wrong-role
  apiGroup: rbac.authorization.k8s.io
EOF
exit 0
