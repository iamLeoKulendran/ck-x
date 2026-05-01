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

FILE=/tmp/exam/q10/cert-expiration.txt
grep -Eq 'apiserver|API Server|api-server' "$FILE" || fail "Report must include apiserver certificate information"
pass "API server certificate is included in report"
