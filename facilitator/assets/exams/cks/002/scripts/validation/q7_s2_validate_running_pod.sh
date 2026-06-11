#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="syscall-guard"

READY=$(kubectl -n "$NS" get deployment event-logger -o jsonpath='{.status.readyReplicas}')
[ "${READY:-0}" = "1" ] || fail "event-logger must have 1 ready replica, got ${READY:-0}"

# Live pod must carry the hardened profile (prevents pass on fresh Unconfined state)
POD_TYPE=$(kubectl -n "$NS" get pods -l app=event-logger -o jsonpath='{.items[0].spec.securityContext.seccompProfile.type}')
[ "$POD_TYPE" = "RuntimeDefault" ] || fail "Running pod seccomp profile is ${POD_TYPE:-unset}, expected RuntimeDefault"

echo "PASS: pod is Running with RuntimeDefault seccomp profile"
exit 0
