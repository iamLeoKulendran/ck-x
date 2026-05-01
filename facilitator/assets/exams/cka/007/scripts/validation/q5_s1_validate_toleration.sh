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
NS=cka-q05
FOUND=$(kubectl get ds node-log-agent -n "$NS" -o jsonpath='{range .spec.template.spec.tolerations[*]}{.key}{":"}{.operator}{":"}{.effect}{"\n"}{end}' 2>/dev/null | grep '^node-role.kubernetes.io/control-plane:Exists:NoSchedule$')
[ -n "$FOUND" ] || fail "control-plane NoSchedule toleration missing"
pass "control-plane toleration exists"
