#!/bin/bash
set -euo pipefail
NS="rev1-q11"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

kubectl -n "$NS" get deployment batch-worker >/dev/null 2>&1 \
  || fail "Deployment batch-worker not found"

REQ=$(kubectl -n "$NS" get deployment batch-worker \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
LIM=$(kubectl -n "$NS" get deployment batch-worker \
  -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")

[ -n "$REQ" ] || fail "batch-worker has no cpu request set"
[ -n "$LIM" ] || fail "batch-worker has no cpu limit set"

# Original broken value was 300m; quota leaves at most 150m after filler-app.
# Valid fix: requests.cpu <= 150m. Convert to millicores for numeric compare.
strip_m() { echo "${1%m}"; }
REQ_M=$(strip_m "$REQ")
LIM_M=$(strip_m "$LIM")

# Reject if candidate left the original 300m value unchanged
[ "$REQ_M" -le 150 ] 2>/dev/null \
  || fail "batch-worker requests.cpu=${REQ} still exceeds remaining quota (need <= 150m)"
[ "$LIM_M" -le 650 ] 2>/dev/null \
  || fail "batch-worker limits.cpu=${LIM} exceeds remaining limits quota"

pass "batch-worker cpu request=${REQ} limit=${LIM} — fits within ResourceQuota"
