#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="supply-scan"

kubectl -n "$NS" get deployment scanner-api >/dev/null 2>&1 || fail "scanner-api deployment missing"

POD=$(kubectl -n "$NS" get pods -l app=scanner-api \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running scanner-api pod found"

IMG=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "$IMG" | grep -q "registry.localhost:5000/ckx/alpine:3.20" \
  || fail "scanner-api pod must use registry.localhost:5000/ckx/alpine:3.20 (got: $IMG)"

READY=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$READY" = "true" ] || fail "scanner-api container is not Ready"

echo "PASS: hardened scanner-api Running from the internal registry image"
exit 0
