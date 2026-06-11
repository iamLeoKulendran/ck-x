#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q2/failed-checks.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"

for id in "1.2.1" "1.2.18" "1.4.1" "4.2.6"; do
  grep -qE "(^|[[:space:]])${id//./\\.}([[:space:]]|$)" "$FILE" || fail "FAIL check $id is missing from failed-checks.txt"
done

LINES=$(grep -cve '^[[:space:]]*$' "$FILE" || true)
[ "$LINES" -eq 4 ] || fail "failed-checks.txt must contain exactly 4 check IDs (one per line), found $LINES non-empty lines"

for id in "1.1.1" "1.2.2" "1.2.9" "3.2.1" "4.1.1"; do
  if grep -qE "(^|[[:space:]])${id//./\\.}([[:space:]]|$)" "$FILE"; then
    fail "failed-checks.txt wrongly includes non-FAIL check $id"
  fi
done

echo "PASS: all four FAIL checks correctly extracted"
exit 0
