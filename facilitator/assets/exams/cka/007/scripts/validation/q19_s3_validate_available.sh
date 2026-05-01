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
NS=cka-q19
kubectl rollout status deploy/quota-api -n "$NS" --timeout=20s >/dev/null 2>&1 || fail "quota-api not available"
AVAIL=$(kubectl get deploy quota-api -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "$AVAIL" = "2" ] || fail "availableReplicas is $AVAIL"
pass "quota-api is available within quota"
