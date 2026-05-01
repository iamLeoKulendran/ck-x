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
kubectl -n "$NS" get role q2-log-reader >/dev/null 2>&1 || fail "Role q2-log-reader missing"
YAML=$(kubectl -n "$NS" get role q2-log-reader -o yaml)
echo "$YAML" | grep -q 'pods/log' || fail "Role must include pods/log"
echo "$YAML" | grep -q 'pods' || fail "Role must include pods"
pass "Role includes Pod and Pod log resources"
