#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q14/secret-reader.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"

CONTENT=$(tr -d '[:space:]' < "$FILE")
[ "$CONTENT" = "mallory@ckx.local" ] || fail "secret-reader.txt does not identify the user who read payroll-db"

echo "PASS: payroll-db secret reader correctly identified"
exit 0
