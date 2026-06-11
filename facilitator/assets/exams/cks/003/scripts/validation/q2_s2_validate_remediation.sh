#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q2/remediation-1.2.1.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"
grep -q -- '--anonymous-auth=false' "$FILE" || fail "remediation must name --anonymous-auth=false"
if grep -q -- 'anonymous-auth=true' "$FILE"; then
  fail "remediation must not set anonymous-auth to true"
fi

echo "PASS: remediation for check 1.2.1 is correct"
exit 0
