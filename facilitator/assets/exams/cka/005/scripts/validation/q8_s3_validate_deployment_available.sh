#!/bin/bash
set -euo pipefail
NS="rev1-q08"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get deployment api-pdb-app >/dev/null 2>&1 || fail "Deployment api-pdb-app not found"
AVAILABLE=$(kubectl -n "$NS" get deployment api-pdb-app \
  -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
[ "${AVAILABLE:-0}" -ge 1 ] || fail "Deployment has ${AVAILABLE:-0} available replicas, expected >= 1"
pass "Deployment api-pdb-app has ${AVAILABLE} available replica(s)"
