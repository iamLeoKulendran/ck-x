#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
[ -f /tmp/exam/q16/list.sh ] || fail "/tmp/exam/q16/list.sh not found"
[ -x /tmp/exam/q16/list.sh ] || fail "/tmp/exam/q16/list.sh is not executable"
OUTPUT=$(bash /tmp/exam/q16/list.sh 2>/dev/null || echo "")
[ -n "$OUTPUT" ] || fail "list.sh produced no output"
echo "$OUTPUT" | grep -iE "TARGET|target" >/dev/null || fail "Script output missing TARGET column header"
echo "$OUTPUT" | grep -iE "SCHEDULE|schedule" >/dev/null || fail "Script output missing SCHEDULE column header"
echo "$OUTPUT" | grep -q "postgres" || fail "Script output missing 'postgres' (weekly-pg CR data)"
pass "list.sh is executable and outputs NAME/TARGET/SCHEDULE columns with CR data"
