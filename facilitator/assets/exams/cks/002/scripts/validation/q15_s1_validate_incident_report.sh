#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q15/incident.txt"

[ -f "$FILE" ] || fail "Incident report $FILE not found"

grep -q "deployment=kernel-helper" "$FILE" || fail "incident.txt must identify the compromised workload as deployment=kernel-helper"

echo "PASS: compromised workload correctly identified"
exit 0
