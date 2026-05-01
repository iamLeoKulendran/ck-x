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
YAML=$(kubectl -n "$NS" get netpol "$NP" -o yaml 2>/dev/null) || fail "NetworkPolicy missing"
echo "$YAML" | grep -q 'role: frontend' || fail "Ingress source must select role=frontend"
echo "$YAML" | grep -q 'port: 5432' || fail "Ingress port must be 5432"
echo "$YAML" | grep -q 'protocol: TCP' || fail "Ingress protocol must be TCP"
pass "NetworkPolicy ingress rule is correct"
