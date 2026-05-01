#!/bin/bash
set +e

fail() {
  echo "❌ $1"
  exit 1
}

pass() {
  echo "✅ $1"
  exit 0
}
COUNT=$(kubectl get nodes -l q06.capture=true --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT" -ge 1 ] || fail "no node has q06.capture=true"
pass "capture node label exists"
