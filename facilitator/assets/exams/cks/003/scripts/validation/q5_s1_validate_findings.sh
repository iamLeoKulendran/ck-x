#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q5/findings.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"
CONTENT=$(tr -d '[:space:]' < "$FILE")
[ "$CONTENT" = "telemetry-public-access" ] || fail "findings.txt does not name the offending ClusterRoleBinding"

echo "PASS: offending ClusterRoleBinding correctly identified"
exit 0
