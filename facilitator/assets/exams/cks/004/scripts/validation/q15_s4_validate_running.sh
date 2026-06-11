#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="runtime-soc"

POD=$(kubectl -n "$NS" get pods -l app=ingest-api \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running ingest-api pod found"

# The Running pod must be single-container (proves the sidecar was removed and rolled out)
N=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[*].name}' | wc -w)
[ "$N" -eq 1 ] || fail "Running ingest-api pod still has $N containers (expected 1)"

IMG=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "$IMG" | grep -q "registry.localhost:5000/ckx/alpine:3.20" \
  || fail "ingest-api pod is not using the internal registry image (got: $IMG)"

READY=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$READY" = "true" ] || fail "ingest-api container is not Ready"

echo "PASS: single-container hardened ingest-api Running from the internal registry image"
exit 0
