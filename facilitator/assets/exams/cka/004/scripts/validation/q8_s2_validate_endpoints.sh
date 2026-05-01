#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q08
EP=$(kubectl get endpoints q8-web-svc -n "$NS" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
[ -n "$EP" ] || fail "Service has no endpoints"
pass "Service endpoints are present"
