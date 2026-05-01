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
DESIRED=$(kubectl get ds node-log-agent -n "$NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
READY=$(kubectl get ds node-log-agent -n "$NS" -o jsonpath='{.status.numberReady}' 2>/dev/null)
[ -n "$DESIRED" ] && [ "$READY" = "$DESIRED" ] || fail "ready pods $READY do not equal desired $DESIRED"
pass "all DaemonSet pods are ready"
