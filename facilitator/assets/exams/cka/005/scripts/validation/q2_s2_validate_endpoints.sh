#!/bin/bash
set -euo pipefail
NS="rev1-q02"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
ENDPOINTS=$(kubectl -n "$NS" get endpoints frontend-svc \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
[ -n "$ENDPOINTS" ] || fail "Service frontend-svc has no ready endpoints"
pass "Service frontend-svc has populated endpoints"
