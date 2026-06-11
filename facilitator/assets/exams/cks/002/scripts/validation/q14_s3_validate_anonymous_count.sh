#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q14/anonymous-denied.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"

CONTENT=$(tr -d '[:space:]' < "$FILE")
[ "$CONTENT" = "4" ] || fail "anonymous-denied.txt must contain the number of denied anonymous requests"

echo "PASS: denied anonymous request count is correct"
exit 0
