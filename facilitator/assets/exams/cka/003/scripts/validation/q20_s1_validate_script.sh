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

FILE=/tmp/exam/q20/inspect_rbac.sh
[ -x "$FILE" ] || fail "inspect_rbac.sh missing or not executable"
grep -q 'kubectl auth can-i' "$FILE" || fail "Script must use kubectl auth can-i"
grep -q -- '--list' "$FILE" || fail "Script must use --list"
pass "RBAC inspection script exists"
