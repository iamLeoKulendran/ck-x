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
NS=cka-q06
DESIRED=$(kubectl get ds packet-capture -n "$NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
READY=$(kubectl get ds packet-capture -n "$NS" -o jsonpath='{.status.numberReady}' 2>/dev/null)
[ "$DESIRED" = "1" ] || fail "desiredNumberScheduled is $DESIRED, expected 1"
[ "$READY" = "1" ] || fail "numberReady is $READY, expected 1"
pass "packet-capture is ready on one labeled node"
