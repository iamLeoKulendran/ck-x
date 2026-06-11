#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="microsvc-restricted"

WARN=$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}')
AUDIT=$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}')

[ "$WARN" = "restricted" ] || fail "namespace warn mode must be restricted (got: ${WARN:-none})"
[ "$AUDIT" = "restricted" ] || fail "namespace audit mode must be restricted (got: ${AUDIT:-none})"

echo "PASS: warn and audit modes both set to restricted"
exit 0
