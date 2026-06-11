#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="immutable-infra"

READY=$(kubectl -n "$NS" get deployment report-writer -o jsonpath='{.status.readyReplicas}')
[ "${READY:-0}" = "1" ] || fail "report-writer must have 1 ready replica, got ${READY:-0}"

# Guard: Ready alone passes on fresh state; immutability must be configured too
ROFS=$(kubectl -n "$NS" get deployment report-writer -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}')
[ "$ROFS" = "true" ] || fail "deployment is Ready but root filesystem is still writable"

echo "PASS: immutable workload is Ready"
exit 0
