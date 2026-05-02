#!/bin/bash
set -euo pipefail
NS="rev1-q03"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
READY=$(kubectl -n "$NS" get deployment web-frontend \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
[ "${READY:-0}" = "3" ] || fail "Expected 3 ready replicas, got '${READY:-0}'"
pass "Deployment web-frontend has 3/3 ready replicas"
