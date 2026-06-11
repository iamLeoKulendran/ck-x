#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="payments"

SA_NAME=$(kubectl -n "$NS" get deployment payment-processor -o jsonpath='{.spec.template.spec.serviceAccountName}')
[ "$SA_NAME" = "payments-runtime" ] || fail "Deployment must use serviceAccountName payments-runtime, got: ${SA_NAME:-default}"

POD_AUTOMOUNT=$(kubectl -n "$NS" get deployment payment-processor -o jsonpath='{.spec.template.spec.automountServiceAccountToken}')
[ "$POD_AUTOMOUNT" = "false" ] || fail "Pod template automountServiceAccountToken must be explicitly false, got: ${POD_AUTOMOUNT:-unset}"

echo "PASS: deployment uses hardened ServiceAccount with automount disabled"
exit 0
