#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="immutable-infra"

# Pick the NEWEST running pod so a terminating old replica is never tested
POD=$(kubectl -n "$NS" get pods -l app=report-writer --field-selector=status.phase=Running \
  --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | tail -1 | cut -d/ -f2)
[ -n "$POD" ] || fail "No running report-writer pod found"

if timeout 12 kubectl -n "$NS" exec "$POD" -- touch /immutable-probe 2>/dev/null; then
  kubectl -n "$NS" exec "$POD" -- rm -f /immutable-probe >/dev/null 2>&1 || true
  fail "Root filesystem is still writable inside the container"
fi

timeout 12 kubectl -n "$NS" exec "$POD" -- ls /data/report.log >/dev/null 2>&1 \
  || fail "Application can no longer write its report log to /data"

echo "PASS: root filesystem immutable at runtime, application still writes to /data"
exit 0
