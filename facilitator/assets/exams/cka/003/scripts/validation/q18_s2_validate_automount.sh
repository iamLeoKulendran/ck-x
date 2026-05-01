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

NS=rbac-sec-q18
POD=q18-token-pod
AM=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.automountServiceAccountToken}' 2>/dev/null)
[ "$AM" = "false" ] || fail "Pod must set automountServiceAccountToken=false"
pass "Pod token automount is disabled"
