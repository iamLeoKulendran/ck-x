#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="supply-trust"

# The authentic manifest deploys trusted-release
kubectl -n "$NS" get deployment trusted-release >/dev/null 2>&1 \
  || fail "trusted-release deployment missing; authentic manifest not applied"

POD=$(kubectl -n "$NS" get pods -l app=trusted-release \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running trusted-release pod found"

# The tampered manifest must NOT have been deployed
if kubectl -n "$NS" get deployment rogue-release >/dev/null 2>&1; then
  fail "rogue-release (tampered manifest) was deployed; it must be rejected"
fi

echo "PASS: only the authentic trusted-release deployment is present"
exit 0
