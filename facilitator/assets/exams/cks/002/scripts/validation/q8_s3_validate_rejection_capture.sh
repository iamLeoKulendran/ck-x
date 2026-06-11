#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="restricted-apps"
FILE="/tmp/exam/q8/rejection.txt"

[ -f "$FILE" ] || fail "Rejection capture file $FILE not found"

grep -q "violates PodSecurity" "$FILE" || fail "$FILE must contain the PodSecurity admission error"

if kubectl -n "$NS" get pod intruder >/dev/null 2>&1; then
  fail "Pod 'intruder' exists; the violating pod must have been rejected"
fi

echo "PASS: violating pod was rejected and the error was captured"
exit 0
