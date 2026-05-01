#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q03
STS=q3-data-store
REPLICAS=$(kubectl get sts "$STS" -n "$NS" -o jsonpath='{.spec.replicas}')
[ "$REPLICAS" = "1" ] || fail "Expected spec.replicas=1, got $REPLICAS"
pass "StatefulSet is scaled to 1 replica"
