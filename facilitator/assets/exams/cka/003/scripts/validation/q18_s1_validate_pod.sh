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

NS=rbac-sec-q18
POD=q18-token-pod
kubectl -n "$NS" get pod "$POD" >/dev/null 2>&1 || fail "Pod q18-token-pod missing"
IMG=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
[ "$IMG" = "nginx:1.25" ] || fail "Pod image must be nginx:1.25"
pass "Pod exists with expected image"
