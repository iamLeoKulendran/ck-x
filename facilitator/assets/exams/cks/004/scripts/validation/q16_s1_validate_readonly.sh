#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="runtime-immutable"

kubectl -n "$NS" get deployment log-rotator >/dev/null 2>&1 || fail "log-rotator deployment missing"
RO=$(kubectl -n "$NS" get deployment log-rotator \
      -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}')
[ "$RO" = "true" ] || fail "log-rotator must set readOnlyRootFilesystem: true (got: ${RO:-unset})"

echo "PASS: log-rotator enforces a read-only root filesystem"
exit 0
