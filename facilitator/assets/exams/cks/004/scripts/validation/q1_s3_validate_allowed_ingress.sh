#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="frontend-zone"

# Guard: both policies must exist, otherwise an open namespace would pass this test
kubectl -n "$NS" get networkpolicy default-deny-ingress >/dev/null 2>&1 \
  || fail "default-deny-ingress missing; lockdown not in place"
kubectl -n "$NS" get networkpolicy allow-trusted-clients >/dev/null 2>&1 \
  || fail "allow-trusted-clients missing; allowed path not configured"

kubectl -n trusted-clients wait --for=condition=Ready pod/client --timeout=60s >/dev/null 2>&1 || true

timeout 25 kubectl -n trusted-clients exec client -- \
  wget -q -T 5 -O /dev/null http://storefront-svc.frontend-zone.svc.cluster.local \
  || fail "trusted-clients/client cannot reach storefront on TCP 80 (this path must stay allowed)"

echo "PASS: trusted client reaches storefront on 80 with policies in place"
exit 0
