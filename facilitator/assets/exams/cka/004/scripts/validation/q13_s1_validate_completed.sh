#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q13
JOB=q13-pi
kubectl get job "$JOB" -n "$NS" >/dev/null 2>&1 || fail "Job $JOB not found"
SUCCEEDED=$(kubectl get job "$JOB" -n "$NS" -o jsonpath='{.status.succeeded}')
[ "$SUCCEEDED" = "1" ] || fail "Job has not completed successfully"
pass "Job completed successfully"
