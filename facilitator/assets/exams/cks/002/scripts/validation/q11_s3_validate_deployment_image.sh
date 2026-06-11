#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="image-audit"
DIR="/tmp/exam/q11"

[ -f "$DIR/safe-image.txt" ] || fail "Answer file $DIR/safe-image.txt not found"
ANSWER=$(tr -d '[:space:]' < "$DIR/safe-image.txt")

IMAGE=$(kubectl -n "$NS" get deployment release-app -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMAGE" = "$ANSWER" ] || fail "release-app image must be the chosen safe image ($ANSWER), got: $IMAGE"
[ "$IMAGE" != "nginx:1.14.2" ] || fail "release-app still runs the vulnerable nginx:1.14.2"

READY=$(kubectl -n "$NS" get deployment release-app -o jsonpath='{.status.readyReplicas}')
[ "${READY:-0}" = "1" ] || fail "release-app must be Ready after the image change, got ${READY:-0}"

echo "PASS: release-app now runs the safest scanned image"
exit 0
