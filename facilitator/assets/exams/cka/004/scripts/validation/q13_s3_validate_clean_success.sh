#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q13
JOB=q13-pi
kubectl get job "$JOB" -n "$NS" >/dev/null 2>&1 || fail "Job $JOB not found"
SUCCEEDED=$(kubectl get job "$JOB" -n "$NS" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
FAILED=$(kubectl get job "$JOB" -n "$NS" -o jsonpath='{.status.failed}' 2>/dev/null || echo "0")
[ "${SUCCEEDED:-0}" -ge 1 ] 2>/dev/null || fail "Job succeeded count is ${SUCCEEDED:-0}, expected >= 1"
[ "${FAILED:-0}" -le 0 ] 2>/dev/null || fail "Job failed count is $FAILED, expected 0 (clean fix, not tolerated failure)"
pass "Job completed cleanly: succeeded=$SUCCEEDED, failed=${FAILED:-0}"
