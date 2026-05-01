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

NS=rbac-sec-q12
kubectl get clusterrole q12-impersonate-limited-user >/dev/null 2>&1 || fail "ClusterRole missing"
kubectl get clusterrolebinding q12-impersonate-limited-user >/dev/null 2>&1 || fail "ClusterRoleBinding missing"
SUBJ=$(kubectl get clusterrolebinding q12-impersonate-limited-user -o jsonpath='{.subjects[0].kind}:{.subjects[0].namespace}:{.subjects[0].name}' 2>/dev/null)
[ "$SUBJ" = "ServiceAccount:$NS:impersonator" ] || fail "ClusterRoleBinding subject must be ${NS}/impersonator"
pass "Impersonation RBAC objects exist"
