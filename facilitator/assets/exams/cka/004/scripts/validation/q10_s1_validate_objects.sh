#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q10
kubectl get sa processor -n "$NS" >/dev/null 2>&1 || fail "ServiceAccount processor not found"
kubectl get role processor -n "$NS" >/dev/null 2>&1 || fail "Role processor not found"
kubectl get rolebinding processor -n "$NS" >/dev/null 2>&1 || fail "RoleBinding processor not found"
pass "RBAC objects exist"
