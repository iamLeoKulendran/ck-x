#!/bin/bash
set -euo pipefail
NS="rev1-q06"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

kubectl -n "$NS" get pod data-processor >/dev/null 2>&1 \
  || fail "Pod data-processor not found"

# Anchor on spec fix — prevents passing during the brief running window before first crash.
READONLY=$(kubectl -n "$NS" get pod data-processor \
  -o jsonpath='{.spec.containers[0].volumeMounts[0].readOnly}' 2>/dev/null || echo "false")
[ "$READONLY" = "true" ] \
  && fail "volumeMount readOnly is still 'true' — spec not yet fixed"

WAITING_REASON=$(kubectl -n "$NS" get pod data-processor \
  -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
[ "$WAITING_REASON" = "CrashLoopBackOff" ] \
  && fail "Pod is still in CrashLoopBackOff"

READY=$(kubectl -n "$NS" get pod data-processor \
  -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
[ "$READY" = "true" ] || fail "Container not ready (state: ${WAITING_REASON:-unknown})"

pass "Container is ready and not in CrashLoopBackOff"
