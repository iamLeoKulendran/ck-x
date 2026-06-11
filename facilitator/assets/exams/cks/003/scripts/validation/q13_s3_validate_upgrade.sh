#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="sbom-audit"

IMAGE=$(kubectl -n "$NS" get deployment web-api -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMAGE" = "nginx:1.27-alpine" ] || fail "web-api must be upgraded to nginx:1.27-alpine, got $IMAGE"

kubectl -n "$NS" rollout status deployment/web-api --timeout=60s >/dev/null 2>&1 || fail "web-api rollout is not complete"

echo "PASS: web-api upgraded and Ready"
exit 0
