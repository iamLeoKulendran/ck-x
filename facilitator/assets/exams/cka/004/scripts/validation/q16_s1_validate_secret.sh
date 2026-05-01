#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q16
SEC=q16-db-secret
kubectl get secret "$SEC" -n "$NS" >/dev/null 2>&1 || fail "Secret $SEC not found"
USER_VAL=$(kubectl get secret "$SEC" -n "$NS" -o jsonpath='{.data.username}')
PASS_VAL=$(kubectl get secret "$SEC" -n "$NS" -o jsonpath='{.data.password}')
[ -n "$USER_VAL" ] || fail "Secret missing username key"
[ -n "$PASS_VAL" ] || fail "Secret missing password key"
[ "$(echo "$USER_VAL" | base64 -d)" = "admin" ] || fail "username value must be admin"
[ "$(echo "$PASS_VAL" | base64 -d)" = "s3cr3t" ] || fail "password value must be s3cr3t"
pass "Secret is correct"
