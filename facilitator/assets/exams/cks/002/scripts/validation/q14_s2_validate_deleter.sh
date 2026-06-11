#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q14/deleter.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"

CONTENT=$(tr -d '[:space:]' < "$FILE")
[ "$CONTENT" = "system:serviceaccount:ci:deploy-bot" ] || fail "deleter.txt does not identify the ServiceAccount that deleted legacy-web"

echo "PASS: deployment deleter correctly identified"
exit 0
