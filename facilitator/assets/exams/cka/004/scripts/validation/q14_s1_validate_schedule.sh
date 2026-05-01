#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q14
CJ=q14-cleanup
kubectl get cronjob "$CJ" -n "$NS" >/dev/null 2>&1 || fail "CronJob $CJ not found"
SCHEDULE=$(kubectl get cronjob "$CJ" -n "$NS" -o jsonpath='{.spec.schedule}')
[ "$SCHEDULE" = "*/5 * * * *" ] || fail "Expected schedule */5 * * * *, got $SCHEDULE"
pass "CronJob schedule is correct"
