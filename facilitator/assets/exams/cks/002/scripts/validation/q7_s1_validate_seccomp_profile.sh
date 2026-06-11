#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="syscall-guard"

kubectl -n "$NS" get deployment event-logger >/dev/null 2>&1 || fail "Deployment event-logger not found"

TYPE=$(kubectl -n "$NS" get deployment event-logger -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}')
[ "$TYPE" = "RuntimeDefault" ] || fail "Pod-level seccompProfile.type must be RuntimeDefault, got: ${TYPE:-unset}"

if kubectl -n "$NS" get deployment event-logger -o json | jq -e '.. | .seccompProfile? | select(.type? == "Unconfined")' >/dev/null 2>&1; then
  fail "Unconfined seccomp profile still present in deployment spec"
fi

echo "PASS: seccomp RuntimeDefault enforced at pod level"
exit 0
