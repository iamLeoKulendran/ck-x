#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="payments"

READY=$(kubectl -n "$NS" get deployment payment-processor -o jsonpath='{.status.readyReplicas}')
[ "${READY:-0}" = "2" ] || fail "Expected 2 ready replicas, got ${READY:-0}"

# Running pods must actually use the hardened SA (prevents pass on fresh state)
POD_SA=$(kubectl -n "$NS" get pods -l app=payment-processor -o jsonpath='{.items[0].spec.serviceAccountName}')
[ "$POD_SA" = "payments-runtime" ] || fail "Running pods still use ServiceAccount: ${POD_SA:-default}"

echo "PASS: rollout complete with hardened ServiceAccount in use"
exit 0
