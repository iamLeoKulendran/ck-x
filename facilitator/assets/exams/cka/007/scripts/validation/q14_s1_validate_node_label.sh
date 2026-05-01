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
COUNT=$(kubectl get nodes -l q14.disk=ssd --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT" -ge 1 ] || fail "no node labeled q14.disk=ssd"
pass "required node label exists"
