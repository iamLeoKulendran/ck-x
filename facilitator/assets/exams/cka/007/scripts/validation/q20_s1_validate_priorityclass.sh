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
VAL=$(kubectl get priorityclass business-critical -o jsonpath='{.value}' 2>/dev/null)
GD=$(kubectl get priorityclass business-critical -o jsonpath='{.globalDefault}' 2>/dev/null)
[ -n "$VAL" ] && [ "$VAL" -ge 100000 ] || fail "PriorityClass value $VAL is too low or missing"
[ "$GD" = "false" ] || [ -z "$GD" ] || fail "globalDefault must be false"
pass "PriorityClass exists with high non-default priority"
