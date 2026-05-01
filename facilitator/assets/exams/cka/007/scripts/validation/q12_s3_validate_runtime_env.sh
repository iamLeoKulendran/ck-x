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
NS=cka-q12
POD=$(kubectl get pod -n "$NS" -l app=payment-worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$POD" ] || fail "payment-worker pod missing"
VAL=$(kubectl exec -n "$NS" "$POD" -- printenv DB_PASSWORD 2>/dev/null)
[ "$VAL" = "s3cr3t" ] || fail "DB_PASSWORD is not the expected value"
pass "Secret value is injected"
