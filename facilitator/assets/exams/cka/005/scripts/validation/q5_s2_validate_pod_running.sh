#!/bin/bash
set -euo pipefail
NS="rev1-q05"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get pod app-pod >/dev/null 2>&1 || fail "Pod app-pod not found in $NS"
STATUS=$(kubectl -n "$NS" get pod app-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[ "$STATUS" = "Running" ] || fail "Pod app-pod phase='$STATUS', expected 'Running'"
pass "Pod app-pod is Running"
