#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q12/verify-result.txt"

[ -f "$FILE" ] || fail "Result file $FILE not found"

grep -q "^release-a.yaml: VERIFIED$" "$FILE" || fail "verify-result.txt must record 'release-a.yaml: VERIFIED'"
grep -q "^release-b.yaml: FAILED$" "$FILE" || fail "verify-result.txt must record 'release-b.yaml: FAILED'"

echo "PASS: signature verification results recorded correctly"
exit 0
