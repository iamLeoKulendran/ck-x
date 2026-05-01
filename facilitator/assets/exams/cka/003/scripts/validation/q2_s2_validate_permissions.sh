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

NS=rbac-sec-q2
USER="system:serviceaccount:${NS}:log-reader"
can_i yes --as="$USER" get pods -n "$NS" || fail "log-reader cannot get pods"
can_i yes --as="$USER" get pods/log -n "$NS" || fail "log-reader cannot get pods/log"
can_i no --as="$USER" delete pods -n "$NS" || fail "log-reader must not delete pods"
pass "log-reader has correct log read permissions"
