#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="batch-ops"

for cj in db-backup report-gen cache-warm; do
  kubectl -n "$NS" get cronjob "$cj" >/dev/null 2>&1 || fail "CronJob $cj not found; do not delete the workloads"
done

[ "$(kubectl -n "$NS" get cronjob cache-warm -o jsonpath='{.spec.suspend}')" = "true" ] || fail "cache-warm must be suspended"
[ "$(kubectl -n "$NS" get cronjob db-backup -o jsonpath='{.spec.suspend}')" != "true" ] || fail "db-backup must stay unsuspended"
[ "$(kubectl -n "$NS" get cronjob report-gen -o jsonpath='{.spec.suspend}')" != "true" ] || fail "report-gen must stay unsuspended"

echo "PASS: only the malicious CronJob is suspended"
exit 0
