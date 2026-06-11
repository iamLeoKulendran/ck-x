#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="edge-zone"

# Guard: the egress policy must exist, otherwise open traffic would pass this test
kubectl -n "$NS" get networkpolicy gateway-egress >/dev/null 2>&1 || fail "gateway-egress policy missing; egress lockdown not in place"

timeout 20 kubectl -n "$NS" exec deploy/gateway-proxy -- wget -q -T 5 -O /dev/null http://orders-api-svc.internal-api.svc \
  || fail "gateway-proxy cannot reach orders-api-svc.internal-api on TCP 80 (this path must stay allowed)"

echo "PASS: allowed egress to internal-api works with the policy in place"
exit 0
