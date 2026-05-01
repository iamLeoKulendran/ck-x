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

NS=rbac-sec-q17
SA=$(kubectl -n "$NS" get deploy q17-private-app -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
[ "$SA" = "image-puller" ] || fail "Deployment must use serviceAccountName image-puller"
pass "Deployment uses image-puller"
