#!/bin/bash
set -euo pipefail
NS="rev1-q11"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
POD=$(kubectl -n "$NS" get pod -l app=batch-worker \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
[ -n "$POD" ] || fail "No pod found with label app=batch-worker"
STATUS=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[ "$STATUS" = "Running" ] || fail "Pod '$POD' phase='$STATUS', expected 'Running'"
pass "batch-worker Pod '$POD' is Running"
