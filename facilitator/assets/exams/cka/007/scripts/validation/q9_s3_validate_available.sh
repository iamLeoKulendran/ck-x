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
NS=cka-q09
kubectl rollout status deploy/slow-api -n "$NS" --timeout=40s >/dev/null 2>&1 || fail "slow-api rollout not available"
AVAIL=$(kubectl get deploy slow-api -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "$AVAIL" = "1" ] || fail "availableReplicas is $AVAIL"
pass "slow-api is available"
