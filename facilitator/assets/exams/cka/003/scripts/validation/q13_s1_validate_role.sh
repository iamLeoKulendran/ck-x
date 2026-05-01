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

NS=rbac-sec-q13
YAML=$(kubectl -n "$NS" get role q13-app-reader -o yaml 2>/dev/null) || fail "Role q13-app-reader missing"
echo "$YAML" | grep -q 'configmaps' || fail "Role must include configmaps"
echo "$YAML" | grep -q 'secrets' && fail "Role must not include secrets"
pass "Role no longer includes secrets"
