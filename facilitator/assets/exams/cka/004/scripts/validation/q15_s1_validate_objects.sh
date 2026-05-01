#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q15
kubectl get configmap app-settings -n "$NS" >/dev/null 2>&1 || fail "ConfigMap app-settings not found"
MODE=$(kubectl get configmap app-settings -n "$NS" -o jsonpath='{.data.APP_MODE}')
[ "$MODE" = "prod" ] || fail "ConfigMap APP_MODE must be prod"
kubectl get pod q15-configured -n "$NS" >/dev/null 2>&1 || fail "Pod q15-configured not found"
pass "ConfigMap and Pod exist"
