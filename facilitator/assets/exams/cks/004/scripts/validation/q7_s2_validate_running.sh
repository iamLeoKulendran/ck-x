#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="syscall-lockdown"

POD=$(kubectl -n "$NS" get pods -l app=metrics-shipper \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running metrics-shipper pod found"

IMG=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "$IMG" | grep -q "registry.localhost:5000/ckx/alpine:3.20" \
  || fail "metrics-shipper pod is not using the internal registry alpine image (got: $IMG)"

# The Running pod must actually carry RuntimeDefault (proves the new spec rolled out)
POD_T=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.securityContext.seccompProfile.type}')
CON_T=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].securityContext.seccompProfile.type}')
[ "$POD_T" = "RuntimeDefault" ] || [ "$CON_T" = "RuntimeDefault" ] \
  || fail "Running metrics-shipper pod does not carry RuntimeDefault seccomp"

READY=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$READY" = "true" ] || fail "metrics-shipper container is not Ready"

echo "PASS: metrics-shipper Running with RuntimeDefault from the internal registry image"
exit 0
