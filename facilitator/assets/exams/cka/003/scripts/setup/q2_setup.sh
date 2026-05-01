#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q2
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete rolebinding q2-read-logs >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q2-log-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa log-reader >/dev/null 2>&1 || true
kubectl -n "$NS" create sa log-reader
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q2-log-reader
  namespace: $NS
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q2-read-logs
  namespace: $NS
subjects:
- kind: ServiceAccount
  name: log-reader
  namespace: $NS
roleRef:
  kind: Role
  name: q2-log-reader
  apiGroup: rbac.authorization.k8s.io
EOF
exit 0
