#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
F="/tmp/exam/q14/findings.txt"

[ -s "$F" ] || fail "findings.txt missing or empty at $F"

USER_LINE=$(grep -E '^user=' "$F" | head -1 | cut -d= -f2-)
[ "$USER_LINE" = "system:serviceaccount:ops:snapshot-sa" ] \
  || fail "user must be system:serviceaccount:ops:snapshot-sa (got: ${USER_LINE:-none})"

echo "PASS: offending user correctly identified"
exit 0
