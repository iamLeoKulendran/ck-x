#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q5/sort_by_age.sh
[ -x "$FILE" ] || fail "$FILE is missing or not executable"
grep -q -- '--sort-by=.metadata.creationTimestamp' "$FILE" || fail "Missing --sort-by=.metadata.creationTimestamp"
bash "$FILE" >/tmp/q5_age.out 2>/tmp/q5_age.err || fail "$FILE failed to run"
grep -q 'NAME' /tmp/q5_age.out || fail "Command output does not look like kubectl pod output"
pass "Age sort script is valid"
