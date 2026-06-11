#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="runtime-immutable"

POD=$(kubectl -n "$NS" get pods -l app=log-rotator \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running log-rotator pod found"

IMG=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "$IMG" | grep -q "registry.localhost:5000/ckx/alpine:3.20" \
  || fail "log-rotator pod is not using the internal registry alpine image (got: $IMG)"

# The Running pod must actually carry the read-only root filesystem (new spec rolled out)
RO=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')
[ "$RO" = "true" ] || fail "Running log-rotator pod does not have readOnlyRootFilesystem: true"

READY=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$READY" = "true" ] || fail "log-rotator container is not Ready"

echo "PASS: immutable log-rotator Running from the internal registry image"
exit 0
