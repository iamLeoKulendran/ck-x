#!/bin/bash
set -euo pipefail
NS="rev1-q11"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get deployment batch-worker >/dev/null 2>&1 || fail "Deployment batch-worker not found"
AVAILABLE=$(kubectl -n "$NS" get deployment batch-worker \
  -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
[ "${AVAILABLE:-0}" -ge 1 ] || fail "Deployment has 0 available replicas — pod still Pending or not Ready"
pass "Deployment batch-worker has ${AVAILABLE} available replica(s)"
