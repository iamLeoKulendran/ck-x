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
can_i yes --as=dev-operator get pods -n "$NS" || fail "dev-operator cannot get pods in $NS"
can_i yes --as=dev-operator list pods -n "$NS" || fail "dev-operator cannot list pods in $NS"
can_i no --as=dev-operator list pods -n default || fail "dev-operator must not list pods in default"
pass "dev-operator namespace permissions are correct"
