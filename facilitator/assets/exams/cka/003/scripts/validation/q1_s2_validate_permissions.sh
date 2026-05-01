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

NS=rbac-sec-q1
USER="system:serviceaccount:${NS}:report-reader"
can_i yes --as="$USER" get pods -n "$NS" || fail "report-reader cannot get pods"
can_i yes --as="$USER" list pods -n "$NS" || fail "report-reader cannot list pods"
can_i no --as="$USER" delete pods -n "$NS" || fail "report-reader must not delete pods"
pass "report-reader has correct least-privilege pod access"
