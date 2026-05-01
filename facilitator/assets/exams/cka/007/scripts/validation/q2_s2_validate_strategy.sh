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
NS=cka-q02
TYPE=$(kubectl get deploy orders-web -n "$NS" -o jsonpath='{.spec.strategy.type}' 2>/dev/null)
MAX_UNAVAIL=$(kubectl get deploy orders-web -n "$NS" -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null)
MAX_SURGE=$(kubectl get deploy orders-web -n "$NS" -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null)
[ "$TYPE" = "RollingUpdate" ] || fail "strategy type is $TYPE"
[ "$MAX_UNAVAIL" = "0" ] || fail "maxUnavailable is $MAX_UNAVAIL, expected 0"
[ "$MAX_SURGE" = "1" ] || fail "maxSurge is $MAX_SURGE, expected 1"
pass "rolling update strategy is safe"
