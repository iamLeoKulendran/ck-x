#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q21/node_report.txt
head -n 1 "$FILE" | grep -Eq 'NODE[[:space:]]+CPU[[:space:]]+MEMORY' || fail "Header must contain NODE CPU MEMORY"
LINES=$(wc -l < "$FILE" | tr -d ' ')
NODES=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
[ "$LINES" -ge $((NODES + 1)) ] || fail "Report does not have enough rows"
pass "Report columns are correct"
