#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="artifact-trust"
FILE="/tmp/exam/q12/verify-result.txt"

[ -f "$FILE" ] || fail "Result file $FILE not found"
grep -q "^release-b.yaml: FAILED$" "$FILE" || fail "Tampered artifact must be recorded as FAILED"

if kubectl -n "$NS" get deployment rogue-api >/dev/null 2>&1; then
  fail "rogue-api is deployed; the tampered manifest must NOT be applied"
fi

echo "PASS: tampered release was identified and not deployed"
exit 0
