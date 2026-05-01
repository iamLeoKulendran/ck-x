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

NS=rbac-sec-q22
DEP=q22-restricted-nginx
kubectl -n "$NS" get deploy "$DEP" >/dev/null 2>&1 || fail "Deployment q22-restricted-nginx missing"
IMG=$(kubectl -n "$NS" get deploy "$DEP" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
REP=$(kubectl -n "$NS" get deploy "$DEP" -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ "$IMG" = "nginx:1.25" ] || fail "Image must be nginx:1.25"
[ "$REP" = "1" ] || fail "replicas must be 1"
pass "Restricted Deployment basics are correct"
