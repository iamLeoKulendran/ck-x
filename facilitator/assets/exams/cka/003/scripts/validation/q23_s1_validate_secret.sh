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

NS=rbac-sec-q23
SEC=q23-db-secret
kubectl -n "$NS" get secret "$SEC" >/dev/null 2>&1 || fail "Secret q23-db-secret missing"
U=$(kubectl -n "$NS" get secret "$SEC" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d 2>/dev/null)
P=$(kubectl -n "$NS" get secret "$SEC" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)
[ "$U" = "admin" ] || fail "username must be admin"
[ "$P" = "s3cr3t" ] || fail "password must be s3cr3t"
pass "Secret data is correct"
