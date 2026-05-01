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
NS=cka-q08
POL=$(kubectl get cronjob db-cleanup -n "$NS" -o jsonpath='{.spec.concurrencyPolicy}' 2>/dev/null)
SUSP=$(kubectl get cronjob db-cleanup -n "$NS" -o jsonpath='{.spec.suspend}' 2>/dev/null)
[ "$POL" = "Forbid" ] || fail "concurrencyPolicy is $POL"
[ "$SUSP" = "false" ] || [ -z "$SUSP" ] || fail "suspend is $SUSP"
pass "CronJob policy and suspend are correct"
