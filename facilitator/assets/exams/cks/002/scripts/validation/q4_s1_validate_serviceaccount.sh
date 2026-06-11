#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="payments"

kubectl -n "$NS" get serviceaccount payments-runtime >/dev/null 2>&1 || fail "ServiceAccount 'payments-runtime' not found in $NS"

AUTOMOUNT=$(kubectl -n "$NS" get serviceaccount payments-runtime -o jsonpath='{.automountServiceAccountToken}')
[ "$AUTOMOUNT" = "false" ] || fail "ServiceAccount automountServiceAccountToken must be false, got: ${AUTOMOUNT:-unset}"

echo "PASS: payments-runtime ServiceAccount exists with automount disabled"
exit 0
