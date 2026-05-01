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

NS=rbac-sec-q5
KIND=$(kubectl -n "$NS" get rolebinding q5-dev-read-pods -o jsonpath='{.subjects[0].kind}' 2>/dev/null)
NAME=$(kubectl -n "$NS" get rolebinding q5-dev-read-pods -o jsonpath='{.subjects[0].name}' 2>/dev/null)
[ "$KIND" = "User" ] || fail "Subject kind must be User"
[ "$NAME" = "dev-operator" ] || fail "Subject name must be dev-operator"
pass "RoleBinding subject is correct"
