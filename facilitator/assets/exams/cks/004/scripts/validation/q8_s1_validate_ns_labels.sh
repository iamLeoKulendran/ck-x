#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="microsvc-restricted"

ENF=$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')
[ "$ENF" = "restricted" ] || fail "namespace must enforce the restricted PSA (got: ${ENF:-none})"

echo "PASS: $NS enforces the restricted Pod Security Standard"
exit 0
