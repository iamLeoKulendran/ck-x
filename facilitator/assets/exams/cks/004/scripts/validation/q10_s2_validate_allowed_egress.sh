#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="txn-mesh"

# Guard: the egress policy must exist, otherwise open egress would pass trivially
kubectl -n "$NS" get networkpolicy processor-egress >/dev/null 2>&1 \
  || fail "processor-egress missing; egress lockdown not in place"

kubectl -n "$NS" rollout status deployment/processor --timeout=60s >/dev/null 2>&1 || true

timeout 25 kubectl -n "$NS" exec deploy/processor -- \
  wget -q -T 5 -O /dev/null http://ledger-svc.txn-ledger.svc.cluster.local \
  || fail "processor cannot reach ledger-svc.txn-ledger on TCP 80 (this path must stay allowed)"

echo "PASS: processor reaches ledger-svc.txn-ledger on 80 with the policy in place"
exit 0
