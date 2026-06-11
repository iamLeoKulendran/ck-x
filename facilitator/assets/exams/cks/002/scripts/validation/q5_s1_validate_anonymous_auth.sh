#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q5/kube-apiserver.yaml"

[ -f "$FILE" ] || fail "Manifest $FILE not found (rerun setup)"

yq eval '.' "$FILE" >/dev/null 2>&1 || fail "Manifest is no longer valid YAML"

CMDS=$(yq eval '.spec.containers[0].command[]' "$FILE")

echo "$CMDS" | grep -q -- '--anonymous-auth=false' || fail "--anonymous-auth must be set to false"
if echo "$CMDS" | grep -q -- '--anonymous-auth=true'; then
  fail "--anonymous-auth=true must be removed"
fi

echo "PASS: anonymous authentication disabled in manifest"
exit 0
