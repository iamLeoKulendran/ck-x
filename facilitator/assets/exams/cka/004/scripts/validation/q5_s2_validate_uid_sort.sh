#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q5/sort_by_uid.sh
[ -x "$FILE" ] || fail "$FILE is missing or not executable"
grep -q -- '--sort-by=.metadata.uid' "$FILE" || fail "Missing --sort-by=.metadata.uid"
bash "$FILE" >/tmp/q5_uid.out 2>/tmp/q5_uid.err || fail "$FILE failed to run"
grep -q 'NAME' /tmp/q5_uid.out || fail "Command output does not look like kubectl pod output"
pass "UID sort script is valid"
