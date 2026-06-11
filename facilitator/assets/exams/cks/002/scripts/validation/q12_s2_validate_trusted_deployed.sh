#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="artifact-trust"

kubectl -n "$NS" get deployment trusted-api >/dev/null 2>&1 || fail "Deployment trusted-api not found; the verified manifest must be applied"

IMAGE=$(kubectl -n "$NS" get deployment trusted-api -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMAGE" = "nginx:1.27-alpine" ] || fail "trusted-api image must be nginx:1.27-alpine, got: $IMAGE"

READY=$(kubectl -n "$NS" get deployment trusted-api -o jsonpath='{.status.readyReplicas}')
[ "${READY:-0}" = "1" ] || fail "trusted-api must be Ready, got ${READY:-0}"

echo "PASS: verified release is deployed and Ready"
exit 0
