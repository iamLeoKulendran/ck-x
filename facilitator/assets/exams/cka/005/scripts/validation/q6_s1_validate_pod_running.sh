#!/bin/bash
set -euo pipefail
NS="rev1-q06"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get pod data-processor >/dev/null 2>&1 || fail "Pod data-processor not found"
STATUS=$(kubectl -n "$NS" get pod data-processor -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[ "$STATUS" = "Running" ] || fail "Pod data-processor phase='$STATUS', expected 'Running'"
pass "Pod data-processor is Running"
