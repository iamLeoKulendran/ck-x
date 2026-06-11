#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="runtime-immutable"

JSON=$(kubectl -n "$NS" get deployment log-rotator -o json 2>/dev/null) || fail "log-rotator deployment missing"

# A volumeMount at /var/spool/app backed by an emptyDir volume
MOUNT_NAME=$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].volumeMounts[]? | select(.mountPath=="/var/spool/app") | .name' | head -1)
[ -n "$MOUNT_NAME" ] || fail "no volume is mounted at /var/spool/app"

echo "$JSON" | jq -e --arg n "$MOUNT_NAME" '[.spec.template.spec.volumes[]? | select(.name==$n) | select(.emptyDir != null)] | length > 0' >/dev/null \
  || fail "the volume mounted at /var/spool/app must be an emptyDir"

echo "PASS: writable emptyDir mounted at /var/spool/app"
exit 0
