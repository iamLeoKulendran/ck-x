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
NS=cka-q11
kubectl rollout status deploy/config-consumer -n "$NS" --timeout=15s >/dev/null 2>&1 || fail "config-consumer not available"
pass "config-consumer is available"
