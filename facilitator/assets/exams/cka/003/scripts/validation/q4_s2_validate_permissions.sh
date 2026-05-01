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

NS=rbac-sec-q4
USER="system:serviceaccount:${NS}:auditor"
can_i yes --as="$USER" list pods -n "$NS" || fail "auditor cannot list pods"
can_i yes --as="$USER" list configmaps -n "$NS" || fail "auditor cannot list configmaps"
can_i no --as="$USER" get secrets -n "$NS" || fail "auditor must not read secrets"
can_i no --as="$USER" delete pods -n "$NS" || fail "auditor must not delete pods"
pass "auditor permissions are least privilege"
