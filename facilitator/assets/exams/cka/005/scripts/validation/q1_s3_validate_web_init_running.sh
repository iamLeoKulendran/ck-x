#!/bin/bash
set -euo pipefail
NS="rev1-q01"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get pod web-init >/dev/null 2>&1 || fail "Pod web-init not found in $NS"
PHASE=$(kubectl -n "$NS" get pod web-init -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[ "$PHASE" = "Running" ] || fail "Pod web-init phase='$PHASE', expected 'Running'"
READY=$(kubectl -n "$NS" get pod web-init -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
[ "$READY" = "true" ] || fail "web-init main container not ready"
pass "Pod web-init is Running — init container completed successfully"
