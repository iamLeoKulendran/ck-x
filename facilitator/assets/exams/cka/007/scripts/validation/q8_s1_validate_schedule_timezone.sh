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
SCHED=$(kubectl get cronjob db-cleanup -n "$NS" -o jsonpath='{.spec.schedule}' 2>/dev/null)
TZ=$(kubectl get cronjob db-cleanup -n "$NS" -o jsonpath='{.spec.timeZone}' 2>/dev/null)
[ "$SCHED" = "*/5 * * * *" ] || fail "schedule is $SCHED"
[ "$TZ" = "Asia/Colombo" ] || fail "timeZone is $TZ"
pass "schedule and timezone are correct"
