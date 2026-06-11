#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="release-pinning"

IMAGE=$(kubectl -n "$NS" get deployment web-frontend -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "$IMAGE" | grep -qE '^nginx@sha256:[0-9a-f]{64}$' || fail "web-frontend image is not digest-pinned yet"
DIGEST="${IMAGE#*@}"

kubectl -n "$NS" rollout status deployment/web-frontend --timeout=60s >/dev/null 2>&1 || fail "web-frontend rollout is not complete"

IMAGE_ID=$(kubectl -n "$NS" get pod -l app=web-frontend --field-selector=status.phase=Running -o jsonpath='{.items[0].status.containerStatuses[0].imageID}' 2>/dev/null || true)
echo "$IMAGE_ID" | grep -q "$DIGEST" || fail "running container imageID does not match the pinned digest"

echo "PASS: rollout complete and the running image matches the pinned digest"
exit 0
