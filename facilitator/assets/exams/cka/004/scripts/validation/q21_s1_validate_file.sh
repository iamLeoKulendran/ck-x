#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q21/node_report.txt
[ -s "$FILE" ] || fail "$FILE is missing or empty"
while IFS= read -r node; do
  [ -z "$node" ] && continue
  grep -qw "$node" "$FILE" || fail "Node $node missing from report"
done < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"
"}{end}')
pass "Report contains all nodes"
