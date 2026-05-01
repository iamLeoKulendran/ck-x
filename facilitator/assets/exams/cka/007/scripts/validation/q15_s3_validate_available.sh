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
NS=cka-q15
kubectl rollout status deploy/analytics-api -n "$NS" --timeout=15s >/dev/null 2>&1 || fail "analytics-api rollout incomplete"
AVAIL=$(kubectl get deploy analytics-api -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "$AVAIL" = "2" ] || fail "availableReplicas is $AVAIL"
pass "analytics-api is available"
