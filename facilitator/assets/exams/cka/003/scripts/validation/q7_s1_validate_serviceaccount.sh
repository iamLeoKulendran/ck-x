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

NS=rbac-sec-q7
kubectl -n "$NS" get sa app-runner >/dev/null 2>&1 || fail "ServiceAccount app-runner missing"
AM=$(kubectl -n "$NS" get sa app-runner -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
[ "$AM" = "false" ] || fail "ServiceAccount app-runner must set automountServiceAccountToken=false"
pass "ServiceAccount token automount is disabled"
