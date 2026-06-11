#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q10/found.txt"
EXPECTED="S3cr3t-Hunter2-9000"

[ -f "$FILE" ] || fail "Answer file $FILE not found"

CONTENT=$(tr -d '[:space:]' < "$FILE")
[ "$CONTENT" = "$EXPECTED" ] || fail "found.txt does not contain the leaked password value"

echo "PASS: leaked credential correctly identified"
exit 0
