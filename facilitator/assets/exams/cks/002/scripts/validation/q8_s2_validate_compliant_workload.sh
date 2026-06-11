#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="restricted-apps"

kubectl -n "$NS" get deployment legacy-api >/dev/null 2>&1 || fail "Deployment legacy-api not found"

JSON=$(kubectl -n "$NS" get deployment legacy-api -o json)
SC=$(echo "$JSON" | jq '.spec.template.spec.containers[0].securityContext // {}')

[ "$(echo "$SC" | jq -r '.privileged // false')" = "false" ] || fail "legacy-api must not be privileged"
[ "$(echo "$SC" | jq -r '.runAsNonRoot // false')" = "true" ] || fail "runAsNonRoot must be true"
[ "$(echo "$SC" | jq -r '.allowPrivilegeEscalation')" = "false" ] || fail "allowPrivilegeEscalation must be false"
echo "$SC" | jq -e '.capabilities.drop | index("ALL")' >/dev/null || fail "capabilities must drop ALL"
[ "$(echo "$SC" | jq -r '.seccompProfile.type // "none"')" = "RuntimeDefault" ] || fail "seccompProfile.type must be RuntimeDefault"

READY=$(echo "$JSON" | jq -r '.status.readyReplicas // 0')
[ "$READY" = "1" ] || fail "legacy-api must be Ready after hardening, got readyReplicas=$READY"

echo "PASS: legacy-api complies with the restricted profile and is Ready"
exit 0
