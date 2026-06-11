#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q14/audit-policy.yaml"

[ -f "$FILE" ] || fail "audit policy $FILE not found"
JSON=$(yq -o=json e '.' "$FILE") || fail "audit-policy.yaml is not valid YAML"

[ "$(echo "$JSON" | jq -r '.apiVersion')" = "audit.k8s.io/v1" ] || fail "apiVersion must be audit.k8s.io/v1"
[ "$(echo "$JSON" | jq -r '.kind')" = "Policy" ] || fail "kind must be Policy"
echo "$JSON" | jq -e '.omitStages | index("RequestReceived")' >/dev/null || fail "omitStages must include RequestReceived"
echo "$JSON" | jq -e '.rules | length >= 4' >/dev/null || fail "the policy must define the four required rules"

echo "PASS: audit policy header and omitStages are correct"
exit 0
