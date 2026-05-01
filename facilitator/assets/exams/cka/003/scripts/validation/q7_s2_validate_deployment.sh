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

NS=rbac-sec-q7
SA=$(kubectl -n "$NS" get deploy q7-api -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
AM=$(kubectl -n "$NS" get deploy q7-api -o jsonpath='{.spec.template.spec.automountServiceAccountToken}' 2>/dev/null)
[ "$SA" = "app-runner" ] || fail "Deployment must use serviceAccountName app-runner"
[ "$AM" = "false" ] || fail "Deployment Pod template must set automountServiceAccountToken=false"
pass "Deployment uses non-automounting ServiceAccount"
