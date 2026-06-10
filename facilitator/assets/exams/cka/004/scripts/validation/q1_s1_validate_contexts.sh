#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
DIR=/tmp/exam/q1
[ -s "$DIR/contexts" ] || fail "Missing or empty $DIR/contexts"
EXPECTED=$(kubectl config get-contexts -o name | sort)
ACTUAL=$(sort "$DIR/contexts")
diff <(echo "$EXPECTED") <(echo "$ACTUAL") >/dev/null \
  || fail "Contexts file does not match exactly. Expected: $(echo $EXPECTED | tr '\n' ' ')"
pass "All kubectl contexts listed correctly in $DIR/contexts"
