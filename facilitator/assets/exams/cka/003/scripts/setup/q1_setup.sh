#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q1
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete rolebinding q1-read-pods q1-bad-read >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q1-pod-reader q1-configmap-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa report-reader wrong-reader >/dev/null 2>&1 || true
kubectl -n "$NS" create sa report-reader
kubectl -n "$NS" create sa wrong-reader
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q1-configmap-reader
  namespace: $NS
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q1-bad-read
  namespace: $NS
subjects:
- kind: ServiceAccount
  name: wrong-reader
  namespace: $NS
roleRef:
  kind: Role
  name: q1-configmap-reader
  apiGroup: rbac.authorization.k8s.io
EOF
exit 0
