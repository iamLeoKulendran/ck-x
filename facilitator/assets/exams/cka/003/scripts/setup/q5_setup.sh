#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q5
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete rolebinding q5-dev-read-pods >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q5-pod-reader >/dev/null 2>&1 || true
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q5-pod-reader
  namespace: $NS
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q5-dev-read-pods
  namespace: $NS
subjects:
- kind: ServiceAccount
  name: dev-operator
  namespace: $NS
roleRef:
  kind: Role
  name: q5-pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
exit 0
