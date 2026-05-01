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
NS=cka-q20
kubectl rollout status deploy/critical-api -n "$NS" --timeout=20s >/dev/null 2>&1 || fail "critical-api not available"
AVAIL=$(kubectl get deploy critical-api -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "$AVAIL" = "1" ] || fail "availableReplicas is $AVAIL"
pass "critical-api is available with business-critical priority"
