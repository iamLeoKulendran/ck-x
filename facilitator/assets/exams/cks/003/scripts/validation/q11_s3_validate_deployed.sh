#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="release-engineering"

kubectl -n "$NS" get deployment webhook-gw >/dev/null 2>&1 || fail "deployment webhook-gw not found in $NS"
IMAGE=$(kubectl -n "$NS" get deployment webhook-gw -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMAGE" = "busybox:1.36" ] || fail "deployed image must be busybox:1.36, got $IMAGE"
[ "$(kubectl -n "$NS" get deployment webhook-gw -o jsonpath='{.spec.template.spec.hostPID}')" != "true" ] || fail "deployed workload still uses hostPID"

kubectl -n "$NS" rollout status deployment/webhook-gw --timeout=60s >/dev/null 2>&1 || fail "webhook-gw rollout is not complete"

echo "PASS: hardened deployment applied and Ready"
exit 0
