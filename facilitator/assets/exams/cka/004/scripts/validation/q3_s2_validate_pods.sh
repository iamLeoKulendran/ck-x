#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q03
COUNT=$(kubectl get pod -n "$NS" -l app=q3-data-store --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT" = "1" ] || fail "Expected 1 q3-data-store Pod, got $COUNT"
pass "Only one managed Pod exists"
