#!/bin/bash
set -euo pipefail
NS="rev1-q14"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
READY=$(kubectl -n "$NS" get deployment api-server \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
[ "${READY:-0}" = "3" ] || fail "Expected 3 ready replicas, got '${READY:-0}'"
ENDPOINTS=$(kubectl -n "$NS" get endpoints api-svc \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
[ -n "$ENDPOINTS" ] || fail "Service api-svc has no populated endpoints"
pass "Deployment has 3/3 ready replicas and endpoints are populated"
