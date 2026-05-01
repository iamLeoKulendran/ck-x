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

NS=rbac-sec-q25
SEC=q25-tls
kubectl -n "$NS" get secret "$SEC" >/dev/null 2>&1 || fail "Secret q25-tls missing"
TYPE=$(kubectl -n "$NS" get secret "$SEC" -o jsonpath='{.type}' 2>/dev/null)
CRT=$(kubectl -n "$NS" get secret "$SEC" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
KEY=$(kubectl -n "$NS" get secret "$SEC" -o jsonpath='{.data.tls\.key}' 2>/dev/null)
[ "$TYPE" = "kubernetes.io/tls" ] || fail "Secret type must be kubernetes.io/tls"
[ -n "$CRT" ] || fail "Secret missing tls.crt"
[ -n "$KEY" ] || fail "Secret missing tls.key"
pass "TLS Secret is correct"
