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
NS=cka-q09
CMD=$(kubectl get deploy slow-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.exec.command[*]}' 2>/dev/null)
PERIOD=$(kubectl get deploy slow-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.periodSeconds}' 2>/dev/null)
echo "$CMD" | grep -q '/tmp/healthy' || fail "livenessProbe does not check /tmp/healthy"
[ -z "$PERIOD" ] || [ "$PERIOD" -ge 2 ] || fail "liveness periodSeconds $PERIOD is too aggressive"
pass "liveness probe is valid"
