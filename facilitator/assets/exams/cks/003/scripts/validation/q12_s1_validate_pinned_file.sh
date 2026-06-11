#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q12/pinned-image.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"
REF=$(tr -d '[:space:]' < "$FILE")
echo "$REF" | grep -qE '^nginx@sha256:[0-9a-f]{64}$' || fail "pinned-image.txt must contain nginx@sha256:<64-hex-digits>"

echo "PASS: digest-pinned reference recorded"
exit 0
