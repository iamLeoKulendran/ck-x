#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="container-hardening"

kubectl -n "$NS" get deployment sensor-agent >/dev/null 2>&1 || fail "Deployment sensor-agent not found"

JSON=$(kubectl -n "$NS" get deployment sensor-agent -o json)

HOSTPID=$(echo "$JSON" | jq -r '.spec.template.spec.hostPID // false')
[ "$HOSTPID" = "false" ] || fail "hostPID must be removed"

SC=$(echo "$JSON" | jq '.spec.template.spec.containers[0].securityContext // {}')

[ "$(echo "$SC" | jq -r '.privileged // false')" = "false" ] || fail "privileged must be removed"
[ "$(echo "$SC" | jq -r '.runAsNonRoot // false')" = "true" ] || fail "runAsNonRoot must be true"
[ "$(echo "$SC" | jq -r '.runAsUser // 0')" = "10001" ] || fail "runAsUser must be 10001"
[ "$(echo "$SC" | jq -r '.allowPrivilegeEscalation')" = "false" ] || fail "allowPrivilegeEscalation must be false"
[ "$(echo "$SC" | jq -r '.readOnlyRootFilesystem // false')" = "true" ] || fail "readOnlyRootFilesystem must be true"
echo "$SC" | jq -e '.capabilities.drop | index("ALL")' >/dev/null || fail "capabilities must drop ALL"
[ "$(echo "$SC" | jq -r '.seccompProfile.type // "none"')" = "RuntimeDefault" ] || fail "seccompProfile.type must be RuntimeDefault"

echo "$JSON" | jq -e '.spec.template.spec.containers[0].resources.limits.cpu' >/dev/null || fail "cpu limit must be set"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].resources.limits.memory' >/dev/null || fail "memory limit must be set"

echo "PASS: container security context fully hardened"
exit 0
