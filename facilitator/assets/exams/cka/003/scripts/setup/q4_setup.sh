#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q4
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl delete clusterrolebinding q4-accidental-admin >/dev/null 2>&1 || true
kubectl -n "$NS" delete rolebinding q4-audit-read >/dev/null 2>&1 || true
kubectl -n "$NS" delete role q4-audit-reader >/dev/null 2>&1 || true
kubectl -n "$NS" delete sa auditor >/dev/null 2>&1 || true
kubectl -n "$NS" create sa auditor
kubectl create clusterrolebinding q4-accidental-admin --clusterrole=cluster-admin --serviceaccount="$NS:auditor"
exit 0
