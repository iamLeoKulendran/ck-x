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
USER="system:serviceaccount:${NS}:reader"
can_i yes --as="$USER" get pods -n "$NS" || fail "reader cannot get pods"
can_i yes --as="$USER" list pods -n "$NS" || fail "reader cannot list pods"
pass "reader has correct pod read permissions"
