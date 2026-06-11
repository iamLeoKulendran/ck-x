#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q7/insecure-api.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"
CONTENT=$(tr -d '[:space:]' < "$FILE")
[ "$CONTENT" = "2375" ] || fail "insecure-api.txt does not identify the unauthenticated container-runtime API port"

echo "PASS: insecure container-runtime API port correctly identified"
exit 0
