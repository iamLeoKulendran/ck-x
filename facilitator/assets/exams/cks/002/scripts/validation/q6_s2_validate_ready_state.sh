#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="container-hardening"

READY=$(kubectl -n "$NS" get deployment sensor-agent -o jsonpath='{.status.readyReplicas}')
[ "${READY:-0}" = "1" ] || fail "sensor-agent must have 1 ready replica, got ${READY:-0}"

# Guard so this cannot pass on the fresh privileged state
NONROOT=$(kubectl -n "$NS" get deployment sensor-agent -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}')
[ "$NONROOT" = "true" ] || fail "deployment is Ready but not hardened (runAsNonRoot missing)"

PRIV=$(kubectl -n "$NS" get deployment sensor-agent -o jsonpath='{.spec.template.spec.containers[0].securityContext.privileged}')
[ "$PRIV" != "true" ] || fail "deployment is still privileged"

echo "PASS: hardened deployment is Ready"
exit 0
