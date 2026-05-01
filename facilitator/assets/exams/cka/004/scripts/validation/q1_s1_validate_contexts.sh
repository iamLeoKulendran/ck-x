#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
DIR=/tmp/exam/q1
[ -s "$DIR/contexts" ] || fail "Missing or empty $DIR/contexts"
while IFS= read -r ctx; do
  [ -z "$ctx" ] && continue
  grep -Fxq "$ctx" "$DIR/contexts" || fail "Context $ctx is missing from contexts file"
done < <(kubectl config get-contexts -o name)
pass "All kubectl contexts are listed"
