#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q5/kube-apiserver.yaml"

[ -f "$FILE" ] || fail "Manifest $FILE not found (rerun setup)"

PLUGINS=$(yq eval '.spec.containers[0].command[]' "$FILE" | grep -- '--enable-admission-plugins=' || true)
[ -n "$PLUGINS" ] || fail "--enable-admission-plugins flag is missing"

echo "$PLUGINS" | grep -q "NodeRestriction" || fail "--enable-admission-plugins must include NodeRestriction"

echo "PASS: NodeRestriction admission plugin enabled"
exit 0
