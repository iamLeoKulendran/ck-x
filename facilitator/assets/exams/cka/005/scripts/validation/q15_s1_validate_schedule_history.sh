#!/bin/bash
set -euo pipefail
NS="rev1-q15"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get cronjob report-gen >/dev/null 2>&1 || fail "CronJob report-gen not found"
SCHEDULE=$(kubectl -n "$NS" get cronjob report-gen \
  -o jsonpath='{.spec.schedule}' 2>/dev/null || echo "")
[ "$SCHEDULE" = "*/5 * * * *" ] || fail "Schedule='$SCHEDULE', expected '*/5 * * * *'"
SUCCESS=$(kubectl -n "$NS" get cronjob report-gen \
  -o jsonpath='{.spec.successfulJobsHistoryLimit}' 2>/dev/null || echo "")
[ "$SUCCESS" = "3" ] || fail "successfulJobsHistoryLimit='$SUCCESS', expected '3'"
FAILED=$(kubectl -n "$NS" get cronjob report-gen \
  -o jsonpath='{.spec.failedJobsHistoryLimit}' 2>/dev/null || echo "")
[ "$FAILED" = "1" ] || fail "failedJobsHistoryLimit='$FAILED', expected '1'"
pass "CronJob schedule=*/5 * * * *, successfulHistoryLimit=3, failedHistoryLimit=1"
