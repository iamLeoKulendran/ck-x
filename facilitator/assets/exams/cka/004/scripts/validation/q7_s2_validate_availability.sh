#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q07
DEP=q7-broken-web
DESIRED=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.spec.replicas}')
AVAILABLE=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.status.availableReplicas}')
[ "$DESIRED" = "2" ] || fail "Expected 2 desired replicas, got $DESIRED"
[ "$AVAILABLE" = "2" ] || fail "Expected 2 available replicas, got ${AVAILABLE:-0}"
pass "Deployment availability is correct"
