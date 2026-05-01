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
kubectl rollout status deploy/orders-web -n "$NS" --timeout=8s >/dev/null 2>&1 || fail "orders-web rollout incomplete"
REPL=$(kubectl get deploy orders-web -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "$REPL" = "4" ] || fail "available replicas is $REPL, expected 4"
pass "orders-web is fully available"
