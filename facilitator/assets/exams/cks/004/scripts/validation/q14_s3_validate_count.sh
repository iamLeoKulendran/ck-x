#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
F="/tmp/exam/q14/findings.txt"
LOG="/tmp/exam/q14/audit.log"

[ -s "$F" ] || fail "findings.txt missing or empty at $F"

COUNT_LINE=$(grep -E '^count=' "$F" | head -1 | cut -d= -f2-)
[ -n "$COUNT_LINE" ] || fail "findings.txt has no count= line"

# Ground truth recomputed from the planted log
TRUTH=$(jq -c 'select(.user.username=="system:serviceaccount:ops:snapshot-sa" and .verb=="get" and .objectRef.resource=="secrets")' "$LOG" | wc -l)

[ "$COUNT_LINE" = "$TRUTH" ] \
  || fail "count must be $TRUTH get-secrets events (got: $COUNT_LINE)"

echo "PASS: get-secrets count is correct ($TRUTH)"
exit 0
