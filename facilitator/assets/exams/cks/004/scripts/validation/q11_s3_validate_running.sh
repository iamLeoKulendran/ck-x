#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="supply-frontend"

POD=$(kubectl -n "$NS" get pods -l app=web-frontend \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running web-frontend pod found"

IMG=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "$IMG" | grep -q "registry.localhost:5000/ckx/nginx@sha256:" \
  || fail "Running web-frontend pod is not using the digest-pinned image (got: $IMG)"

READY=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$READY" = "true" ] || fail "web-frontend container is not Ready"

echo "PASS: web-frontend Running with the digest-pinned image"
exit 0
