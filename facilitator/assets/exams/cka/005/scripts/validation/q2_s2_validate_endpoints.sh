#!/bin/bash
set -euo pipefail
NS="rev1-q02"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

kubectl -n "$NS" get endpoints frontend-svc >/dev/null 2>&1 \
  || fail "Endpoints object for frontend-svc not found"

ADDR=$(kubectl -n "$NS" get endpoints frontend-svc \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
[ -n "$ADDR" ] || fail "Service frontend-svc has no ready endpoint addresses"

# Endpoint port reflects the targetPort value — must be 8080 after fix (was 80 before).
PORT=$(kubectl -n "$NS" get endpoints frontend-svc \
  -o jsonpath='{.subsets[0].ports[0].port}' 2>/dev/null || echo "")
[ "$PORT" = "8080" ] \
  || fail "Endpoint port='$PORT', expected 8080 — targetPort not yet corrected"

pass "Service frontend-svc endpoints are populated with port 8080"
