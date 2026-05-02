#!/bin/bash
set -euo pipefail
NS="rev1-q06"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

kubectl -n "$NS" get pod data-processor >/dev/null 2>&1 \
  || fail "Pod data-processor not found"

# Anchor on spec fix first — phase=Running is unreliable during CrashLoopBackOff timing windows.
# The broken pod has readOnly=true in spec regardless of when the check runs.
READONLY=$(kubectl -n "$NS" get pod data-processor \
  -o jsonpath='{.spec.containers[0].volumeMounts[0].readOnly}' 2>/dev/null || echo "false")
[ "$READONLY" = "true" ] \
  && fail "volumeMount still has readOnly=true — delete and recreate the Pod with the fix applied"

STATUS=$(kubectl -n "$NS" get pod data-processor \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[ "$STATUS" = "Running" ] || fail "Pod data-processor phase='$STATUS', expected 'Running'"

pass "Pod data-processor spec is fixed (no readOnly) and phase is Running"
