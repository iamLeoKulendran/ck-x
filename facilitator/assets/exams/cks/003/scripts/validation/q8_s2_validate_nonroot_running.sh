#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="checkout"

kubectl -n "$NS" rollout status deployment/checkout-api --timeout=60s >/dev/null 2>&1 || fail "checkout-api rollout is not complete"

UID_IN_POD=$(timeout 20 kubectl -n "$NS" exec deploy/checkout-api -- id -u 2>/dev/null || true)
[ -n "$UID_IN_POD" ] || fail "could not determine the container UID"
[ "$UID_IN_POD" != "0" ] || fail "container process is running as root"

echo "PASS: checkout-api is Ready and runs as UID $UID_IN_POD"
exit 0
