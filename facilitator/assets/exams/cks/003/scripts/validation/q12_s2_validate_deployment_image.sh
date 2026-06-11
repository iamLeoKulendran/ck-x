#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="release-pinning"
FILE="/tmp/exam/q12/pinned-image.txt"

[ -f "$FILE" ] || fail "complete step 1 first; $FILE missing"
REF=$(tr -d '[:space:]' < "$FILE")

IMAGE=$(kubectl -n "$NS" get deployment web-frontend -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "$IMAGE" | grep -qE '^nginx@sha256:[0-9a-f]{64}$' || fail "web-frontend image must be a digest-pinned reference, got $IMAGE"
[ "$IMAGE" = "$REF" ] || fail "deployment image ($IMAGE) does not match the pinned reference in pinned-image.txt"

echo "PASS: web-frontend uses the digest-pinned reference"
exit 0
