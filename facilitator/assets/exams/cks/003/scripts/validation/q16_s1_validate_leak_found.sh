#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q16/leaked-token.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"
CONTENT=$(tr -d '[:space:]' < "$FILE")
[ "$CONTENT" = "ntfy_8d31f7c2a99e" ] || fail "leaked-token.txt does not contain the leaked credential value"

echo "PASS: leaked credential recovered from the logs"
exit 0
