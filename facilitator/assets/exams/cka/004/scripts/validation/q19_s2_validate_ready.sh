#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q19
POD=q19-broken
PHASE=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.phase}')
READY=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$PHASE" = "Running" ] || fail "Pod phase must be Running, got $PHASE"
[ "$READY" = "true" ] || fail "Pod container is not ready"
pass "Pod is running and ready"
