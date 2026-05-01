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
CMD=$(kubectl get deploy slow-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].startupProbe.exec.command[*]}' 2>/dev/null)
THRESH=$(kubectl get deploy slow-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].startupProbe.failureThreshold}' 2>/dev/null)
echo "$CMD" | grep -q '/tmp/healthy' || fail "startupProbe does not check /tmp/healthy"
[ -n "$THRESH" ] && [ "$THRESH" -ge 20 ] || fail "startupProbe failureThreshold $THRESH is too low"
pass "startupProbe allows slow startup"
