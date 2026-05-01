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

NS=rbac-sec-q24
USER="system:serviceaccount:${NS}:token-rotator"
can_i yes --as="$USER" update secrets/app-token -n "$NS" || fail "token-rotator cannot update app-token"
can_i no --as="$USER" update secrets/other-token -n "$NS" || fail "token-rotator must not update other-token"
can_i no --as="$USER" delete secrets/app-token -n "$NS" || fail "token-rotator must not delete app-token"
pass "token-rotator permissions are limited to app-token"
