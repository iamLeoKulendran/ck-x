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
LINE=$(kubectl get deploy reserved-api -n "$NS" -o jsonpath='{range .spec.template.spec.tolerations[*]}{.key}{":"}{.value}{":"}{.effect}{":"}{.tolerationSeconds}{"\n"}{end}' 2>/dev/null | grep '^q16.evict:reserved:NoExecute:300$')
[ -n "$LINE" ] || fail "bounded q16.evict NoExecute toleration missing"
kubectl rollout status deploy/reserved-api -n "$NS" --timeout=20s >/dev/null 2>&1 || fail "reserved-api not available"
pass "NoExecute toleration exists and workload is available"
