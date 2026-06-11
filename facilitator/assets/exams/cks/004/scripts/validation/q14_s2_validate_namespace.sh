#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
F="/tmp/exam/q14/findings.txt"

[ -s "$F" ] || fail "findings.txt missing or empty at $F"

NS_LINE=$(grep -E '^namespace=' "$F" | head -1 | cut -d= -f2-)
[ "$NS_LINE" = "vault-system" ] \
  || fail "namespace must be vault-system (got: ${NS_LINE:-none})"

echo "PASS: target namespace correctly identified"
exit 0
