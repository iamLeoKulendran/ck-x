#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
DIR="/tmp/exam/q11"

[ -f "$DIR/safe-image.txt" ] || fail "Answer file $DIR/safe-image.txt not found"

count_critical() {
  jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$1" 2>/dev/null || echo 999999
}

declare -A COUNTS
COUNTS["nginx:1.14.2"]=$(count_critical "$DIR/nginx.json")
COUNTS["python:3.4-alpine"]=$(count_critical "$DIR/python.json")
COUNTS["alpine:3.20"]=$(count_critical "$DIR/alpine.json")

MIN=999999
for img in "${!COUNTS[@]}"; do
  c=${COUNTS[$img]}
  if [ "$c" -lt "$MIN" ]; then MIN=$c; fi
done

ANSWER=$(tr -d '[:space:]' < "$DIR/safe-image.txt")
[ -n "$ANSWER" ] || fail "safe-image.txt is empty"

ANSWER_COUNT="${COUNTS[$ANSWER]:-}"
[ -n "$ANSWER_COUNT" ] || fail "safe-image.txt must contain one of the three scanned image references, got: $ANSWER"
[ "$ANSWER_COUNT" -eq "$MIN" ] || fail "$ANSWER has $ANSWER_COUNT CRITICAL findings; the safest image has $MIN"

echo "PASS: safest image correctly identified ($ANSWER, $MIN CRITICAL findings)"
exit 0
