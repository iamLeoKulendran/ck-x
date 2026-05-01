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
ROLE=q24-token-rotator
kubectl -n "$NS" get role "$ROLE" >/dev/null 2>&1 || fail "Role q24-token-rotator missing"
RES=$(kubectl -n "$NS" get role "$ROLE" -o jsonpath='{.rules[0].resources[*]}' 2>/dev/null)
RN=$(kubectl -n "$NS" get role "$ROLE" -o jsonpath='{.rules[0].resourceNames[*]}' 2>/dev/null)
VERBS=$(kubectl -n "$NS" get role "$ROLE" -o jsonpath='{.rules[0].verbs[*]}' 2>/dev/null)
echo "$RES" | grep -qw secrets || fail "Role must target secrets"
echo "$RN" | grep -qw app-token || fail "Role must restrict resourceNames to app-token"
for v in get update patch; do echo "$VERBS" | grep -qw "$v" || fail "Role missing verb $v"; done
pass "Role is resourceName-restricted"
