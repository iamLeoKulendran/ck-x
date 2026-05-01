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
USER="system:serviceaccount:${NS}:app-reader"
can_i yes --as="$USER" get configmaps -n "$NS" || fail "app-reader cannot get configmaps"
can_i yes --as="$USER" list configmaps -n "$NS" || fail "app-reader cannot list configmaps"
can_i no --as="$USER" get secrets -n "$NS" || fail "app-reader must not get secrets"
pass "Secret access removed"
