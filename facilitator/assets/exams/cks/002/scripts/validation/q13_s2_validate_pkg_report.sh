#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q13/pkg-report.txt"

[ -f "$FILE" ] || fail "Package report $FILE not found"

grep -qi "^busybox=present$" "$FILE" || fail "pkg-report.txt must contain 'busybox=present'"
grep -qi "^bash=absent$" "$FILE" || fail "pkg-report.txt must contain 'bash=absent'"

echo "PASS: package presence correctly determined from the SBOM"
exit 0
