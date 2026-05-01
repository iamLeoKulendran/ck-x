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
NS=cka-q18
kubectl rollout status deploy/pay-api -n "$NS" --timeout=30s >/dev/null 2>&1 || fail "pay-api not available"
AVAIL=$(kubectl get deploy pay-api -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "$AVAIL" = "4" ] || fail "availableReplicas is $AVAIL"
NODES=$(kubectl get pods -n "$NS" -l app=pay-api -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l | tr -d ' ')
[ "$NODES" -ge 2 ] || fail "pods are not spread across at least two nodes"
pass "pay-api is available and spread"
