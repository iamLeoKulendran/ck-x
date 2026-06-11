#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="immutable-infra"

kubectl -n "$NS" get deployment report-writer >/dev/null 2>&1 || fail "Deployment report-writer not found"

JSON=$(kubectl -n "$NS" get deployment report-writer -o json)

ROFS=$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem // false')
[ "$ROFS" = "true" ] || fail "readOnlyRootFilesystem must be true"

echo "$JSON" | jq -e '.spec.template.spec.volumes[] | select(.emptyDir != null)' >/dev/null \
  || fail "An emptyDir volume must be defined for the writable data path"

MOUNT=$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].volumeMounts[]? | select(.mountPath=="/data") | .name // empty')
[ -n "$MOUNT" ] || fail "A volume must be mounted at /data"

echo "$JSON" | jq -e --arg n "$MOUNT" '.spec.template.spec.volumes[] | select(.name==$n and .emptyDir != null)' >/dev/null \
  || fail "The /data mount must use an emptyDir volume"

echo "PASS: immutable container spec with writable emptyDir at /data"
exit 0
