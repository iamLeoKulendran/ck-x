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
POD=$(kubectl get pod -n "$NS" -l app=config-consumer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$POD" ] || fail "config-consumer pod missing"
VAL=$(kubectl exec -n "$NS" "$POD" -- printenv APP_MODE 2>/dev/null)
[ "$VAL" = "production" ] || fail "APP_MODE is $VAL, expected production"
pass "APP_MODE is injected correctly"
