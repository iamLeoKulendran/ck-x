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

NS=rbac-sec-q3
GROUPS=$(kubectl -n "$NS" get role q3-deployment-reader -o jsonpath='{.rules[*].apiGroups[*]}' 2>/dev/null)
echo "$GROUPS" | grep -qw apps || fail "Role must use apiGroups: [apps]"
RES=$(kubectl -n "$NS" get role q3-deployment-reader -o jsonpath='{.rules[*].resources[*]}' 2>/dev/null)
echo "$RES" | grep -qw deployments || fail "Role must target deployments"
pass "Role uses correct API group"
