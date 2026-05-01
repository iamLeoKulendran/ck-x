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

NS=rbac-sec-q16
NP=q16-db-ingress
kubectl -n "$NS" get netpol "$NP" >/dev/null 2>&1 || fail "NetworkPolicy q16-db-ingress missing"
SEL=$(kubectl -n "$NS" get netpol "$NP" -o jsonpath='{.spec.podSelector.matchLabels.role}' 2>/dev/null)
TYPES=$(kubectl -n "$NS" get netpol "$NP" -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null)
[ "$SEL" = "db" ] || fail "podSelector must be role=db"
echo "$TYPES" | grep -qw Ingress || fail "policyTypes must include Ingress"
pass "NetworkPolicy selector is correct"
