#!/bin/bash
set +e
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NS=rbac-sec-q6
kubectl get clusterrole q6-node-reader >/dev/null 2>&1 || fail "ClusterRole q6-node-reader missing"
kubectl get clusterrolebinding q6-node-reader-binding >/dev/null 2>&1 || fail "ClusterRoleBinding q6-node-reader-binding missing"
SUBJ=$(kubectl get clusterrolebinding q6-node-reader-binding -o jsonpath='{.subjects[0].kind}:{.subjects[0].namespace}:{.subjects[0].name}' 2>/dev/null)
[ "$SUBJ" = "ServiceAccount:$NS:node-inspector" ] || fail "ClusterRoleBinding subject must be ${NS}/node-inspector"
pass "Cluster-scoped RBAC objects exist"
