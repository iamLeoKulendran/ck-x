#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="restricted-apps"

ENFORCE=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')
[ "$ENFORCE" = "restricted" ] || fail "Namespace must enforce the restricted Pod Security Standard, got: ${ENFORCE:-unset}"

echo "PASS: namespace enforces the restricted profile"
exit 0
