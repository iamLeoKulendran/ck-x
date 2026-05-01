#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q10
USER="system:serviceaccount:${NS}:processor"
[ "$(kubectl auth can-i create secrets -n "$NS" --as "$USER")" = "yes" ] || fail "processor cannot create secrets"
[ "$(kubectl auth can-i create configmaps -n "$NS" --as "$USER")" = "yes" ] || fail "processor cannot create configmaps"
[ "$(kubectl auth can-i delete pods -n "$NS" --as "$USER")" = "no" ] || fail "processor should not be able to delete pods"
pass "RBAC permissions are correct"
