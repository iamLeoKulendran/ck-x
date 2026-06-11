#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="node-ops"

kubectl -n "$NS" get deployment host-inspector >/dev/null 2>&1 || fail "deployment host-inspector not found"
JSON=$(kubectl -n "$NS" get deployment host-inspector -o json)

[ "$(echo "$JSON" | jq -r '.spec.template.spec.hostNetwork // false')" = "false" ] || fail "hostNetwork must be removed"
[ "$(echo "$JSON" | jq -r '.spec.template.spec.hostPID // false')" = "false" ] || fail "hostPID must be removed"
echo "$JSON" | jq -e '[.spec.template.spec.volumes[]? | select(.hostPath)] | length == 0' >/dev/null || fail "hostPath volumes must be removed"

echo "PASS: host namespaces and hostPath volumes removed"
exit 0
