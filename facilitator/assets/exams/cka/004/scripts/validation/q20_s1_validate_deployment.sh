#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q20
DEP=q20-api
kubectl get deploy "$DEP" -n "$NS" >/dev/null 2>&1 || fail "Deployment $DEP not found"
REPL=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.spec.replicas}')
[ "$REPL" = "2" ] || fail "Expected 2 replicas, got $REPL"
pass "Deployment exists"
