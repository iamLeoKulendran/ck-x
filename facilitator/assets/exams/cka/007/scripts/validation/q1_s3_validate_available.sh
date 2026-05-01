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
NS=cka-q01
kubectl rollout status deploy/frontend-api -n "$NS" --timeout=8s >/dev/null 2>&1 || fail "frontend-api rollout is not complete"
AVAILABLE=$(kubectl get deploy frontend-api -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "$AVAILABLE" = "3" ] || fail "available replicas is $AVAILABLE, expected 3"
pass "frontend-api rollout is healthy"
