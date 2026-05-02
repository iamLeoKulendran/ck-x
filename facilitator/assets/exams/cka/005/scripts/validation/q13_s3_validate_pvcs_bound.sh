#!/bin/bash
set -euo pipefail
NS="rev1-q13"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
PHASES=$(kubectl -n "$NS" get pvc -l app=cache-cluster \
  -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
if [ -z "$PHASES" ]; then
  # Fallback: get all PVCs in namespace
  PHASES=$(kubectl -n "$NS" get pvc -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
fi
[ -n "$PHASES" ] || fail "No PVCs found in namespace $NS"
if echo "$PHASES" | grep -qE "Pending|Lost"; then
  fail "Some PVCs are not Bound: $PHASES"
fi
pass "All PVCs are Bound"
