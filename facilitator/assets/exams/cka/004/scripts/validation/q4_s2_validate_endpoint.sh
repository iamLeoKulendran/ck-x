#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q04
kubectl get pod dependency-server -n "$NS" >/dev/null 2>&1 || fail "dependency-server Pod not found"
LABEL=$(kubectl get pod dependency-server -n "$NS" -o jsonpath='{.metadata.labels.app}')
[ "$LABEL" = "dependency" ] || fail "dependency-server must have label app=dependency"
EP=$(kubectl get endpoints service-check -n "$NS" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
[ -n "$EP" ] || fail "service-check has no endpoint"
pass "Service endpoint is present"
