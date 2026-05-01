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
kubectl rollout status deploy/payment-worker -n "$NS" --timeout=15s >/dev/null 2>&1 || fail "payment-worker is not available"
pass "payment-worker is available"
