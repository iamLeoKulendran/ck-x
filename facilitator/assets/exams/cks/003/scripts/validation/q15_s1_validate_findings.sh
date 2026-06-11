#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q15/findings.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"

FIRST=$(grep -ve '^[[:space:]]*$' "$FILE" | head -1 | tr -d '[:space:]')
[ "$FIRST" = "cache-warm" ] || fail "line 1 of findings.txt must name the malicious CronJob"
grep -q '203\.0\.113\.66' "$FILE" || fail "findings.txt must contain the contacted IP address"

echo "PASS: malicious CronJob and exfiltration endpoint identified"
exit 0
