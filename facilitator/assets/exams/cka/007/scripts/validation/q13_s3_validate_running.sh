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
NS=cka-q13
PHASE=$(kubectl get pod pinned-cache -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod pinned-cache -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
[ "$PHASE" = "Running" ] || fail "phase is $PHASE"
[ "$READY" = "true" ] || fail "container is not ready"
pass "pinned-cache is running and ready"
