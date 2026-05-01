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
NS=cka-q16
TOLS=$(kubectl get deploy reserved-api -n "$NS" -o jsonpath='{range .spec.template.spec.tolerations[*]}{.key}{":"}{.operator}{":"}{.value}{":"}{.effect}{"\n"}{end}' 2>/dev/null)
echo "$TOLS" | grep -q '^q16.pool:Equal:reserved:NoSchedule$' || fail "q16.pool NoSchedule toleration missing"
echo "$TOLS" | grep -q '^q16.soft:Equal:reserved:PreferNoSchedule$' || fail "q16.soft PreferNoSchedule toleration missing"
pass "NoSchedule and PreferNoSchedule tolerations exist"
