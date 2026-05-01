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

NS=rbac-sec-q4
kubectl get clusterrolebinding q4-accidental-admin >/dev/null 2>&1 && fail "q4-accidental-admin must be removed"
kubectl -n "$NS" get role q4-audit-reader >/dev/null 2>&1 || fail "Role q4-audit-reader missing"
kubectl -n "$NS" get rolebinding q4-audit-read >/dev/null 2>&1 || fail "RoleBinding q4-audit-read missing"
SUBJ=$(kubectl -n "$NS" get rolebinding q4-audit-read -o jsonpath='{.subjects[0].kind}:{.subjects[0].namespace}:{.subjects[0].name}')
[ "$SUBJ" = "ServiceAccount:$NS:auditor" ] || fail "RoleBinding must bind ${NS}/auditor"
pass "Broad binding removed and namespace RBAC exists"
