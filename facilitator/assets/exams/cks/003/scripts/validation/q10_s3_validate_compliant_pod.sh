#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="storage-guard"

kubectl -n "$NS" get pod safe-cache >/dev/null 2>&1 || fail "pod safe-cache not found in $NS"
JSON=$(kubectl -n "$NS" get pod safe-cache -o json)

[ "$(echo "$JSON" | jq -r '.status.phase')" = "Running" ] || fail "safe-cache is not Running"
echo "$JSON" | jq -e '[.spec.volumes[]? | select(.emptyDir != null and .name=="cache")] | length > 0' >/dev/null \
  || fail "safe-cache must use an emptyDir volume named cache"
echo "$JSON" | jq -e '[.spec.volumes[]? | select(.hostPath)] | length == 0' >/dev/null || fail "safe-cache must not use hostPath"
echo "$JSON" | jq -e '[.spec.containers[].volumeMounts[]? | select(.mountPath=="/cache")] | length > 0' >/dev/null \
  || fail "the cache volume must be mounted at /cache"

echo "PASS: compliant pod safe-cache runs with emptyDir storage"
exit 0
