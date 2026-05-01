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

NS=rbac-sec-q11
kubectl -n "$NS" get rolebinding q11-read-pods >/dev/null 2>&1 || fail "RoleBinding q11-read-pods missing"
REF=$(kubectl -n "$NS" get rolebinding q11-read-pods -o jsonpath='{.roleRef.kind}:{.roleRef.name}' 2>/dev/null)
[ "$REF" = "Role:q11-pod-reader" ] || fail "RoleBinding must reference Role q11-pod-reader"
pass "RoleBinding roleRef is correct"
