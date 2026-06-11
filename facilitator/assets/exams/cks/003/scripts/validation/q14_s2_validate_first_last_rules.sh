#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q14/audit-policy.yaml"

[ -f "$FILE" ] || fail "audit policy $FILE not found"
JSON=$(yq -o=json e '.' "$FILE") || fail "audit-policy.yaml is not valid YAML"

echo "$JSON" | jq -e '.rules[0] | (.level == "RequestResponse") and ([.resources[]?.resources[]?] | index("secrets"))' >/dev/null \
  || fail "the FIRST rule must log secrets at RequestResponse"
echo "$JSON" | jq -e '.rules[-1] | (.level == "Metadata") and (has("resources") | not) and (has("users") | not)' >/dev/null \
  || fail "the LAST rule must be an unfiltered Metadata catch-all"

echo "PASS: secrets rule first and Metadata catch-all last"
exit 0
