#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="microsvc-restricted"

POD=$(kubectl -n "$NS" get pods -l app=orders-ui \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running orders-ui pod found"

IMG=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "$IMG" | grep -q "registry.localhost:5000/ckx/alpine:3.20" \
  || fail "orders-ui pod is not using the internal registry image (got: $IMG)"

SC=$(kubectl -n "$NS" get "$POD" -o json | jq '.spec.containers[0].securityContext')
echo "$SC" | jq -e '.allowPrivilegeEscalation == false' >/dev/null \
  || fail "orders-ui must set allowPrivilegeEscalation: false"
echo "$SC" | jq -e '.capabilities.drop | index("ALL")' >/dev/null \
  || fail "orders-ui must drop ALL capabilities"

RNR_POD=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.securityContext.runAsNonRoot}')
RNR_CON=$(echo "$SC" | jq -r '.runAsNonRoot // empty')
[ "$RNR_POD" = "true" ] || [ "$RNR_CON" = "true" ] \
  || fail "orders-ui must set runAsNonRoot: true"

READY=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$READY" = "true" ] || fail "orders-ui container is not Ready"

echo "PASS: compliant orders-ui pod Running from the internal registry image"
exit 0
