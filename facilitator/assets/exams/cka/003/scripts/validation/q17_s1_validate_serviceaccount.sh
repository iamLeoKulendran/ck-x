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
kubectl -n "$NS" get secret q17-regcred >/dev/null 2>&1 || fail "q17-regcred secret missing"
kubectl -n "$NS" get sa image-puller >/dev/null 2>&1 || fail "ServiceAccount image-puller missing"
IPS=$(kubectl -n "$NS" get sa image-puller -o jsonpath='{.imagePullSecrets[*].name}' 2>/dev/null)
echo "$IPS" | grep -qw q17-regcred || fail "image-puller must reference imagePullSecret q17-regcred"
pass "ServiceAccount imagePullSecret is configured"
