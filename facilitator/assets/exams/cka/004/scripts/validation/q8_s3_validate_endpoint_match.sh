#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q08
SVC=q8-web-svc
kubectl get endpoints "$SVC" -n "$NS" >/dev/null 2>&1 || fail "Endpoints $SVC not found"
ADDRS=$(kubectl get endpoints "$SVC" -n "$NS" -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null || echo "")
COUNT=$(echo "$ADDRS" | tr ' ' '\n' | grep -cv '^$' || true)
[ "${COUNT:-0}" -ge 2 ] 2>/dev/null || fail "Endpoints have $COUNT addresses, expected >= 2 (matching deployment replicas)"
PORT=$(kubectl get endpoints "$SVC" -n "$NS" -o jsonpath='{.subsets[0].ports[0].port}' 2>/dev/null || echo "")
[ "$PORT" = "80" ] || fail "Endpoint port is '$PORT', expected 80"
pass "Endpoints have $COUNT addresses on port 80"
