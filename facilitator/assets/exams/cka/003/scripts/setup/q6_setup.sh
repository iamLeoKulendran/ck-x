#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q6
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete clusterrolebinding q6-node-reader-binding >/dev/null 2>&1 || true
kubectl delete clusterrole q6-node-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete rolebinding q6-bad-node-reader-binding >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q6-bad-node-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa node-inspector >/dev/null 2>&1 || true
kubectl -n "$NS" create sa node-inspector
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q6-bad-node-reader
  namespace: $NS
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q6-bad-node-reader-binding
  namespace: $NS
subjects:
- kind: ServiceAccount
  name: node-inspector
  namespace: $NS
roleRef:
  kind: Role
  name: q6-bad-node-reader
  apiGroup: rbac.authorization.k8s.io
EOF
exit 0
