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
NS=cka-q05
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
DESIRED=$(kubectl get ds node-log-agent -n "$NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
[ "$DESIRED" = "$NODE_COUNT" ] || fail "desiredNumberScheduled is $DESIRED, expected $NODE_COUNT"
pass "DaemonSet targets every node"
