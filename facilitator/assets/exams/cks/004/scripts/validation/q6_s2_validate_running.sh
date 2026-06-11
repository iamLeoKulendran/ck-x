#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="system-lockdown"

# Find a Running edge-cache pod that actually carries the hardened context at runtime
POD=$(kubectl -n "$NS" get pods -l app=edge-cache \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running edge-cache pod found"

IMG=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "$IMG" | grep -q "registry.localhost:5000/ckx/alpine:3.20" \
  || fail "edge-cache pod is not using registry.localhost:5000/ckx/alpine:3.20 (got: $IMG)"

RO=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')
[ "$RO" = "true" ] || fail "Running edge-cache pod does not have readOnlyRootFilesystem: true"

READY=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$READY" = "true" ] || fail "edge-cache container is not Ready"

echo "PASS: hardened edge-cache pod is Running from the internal registry image"
exit 0
