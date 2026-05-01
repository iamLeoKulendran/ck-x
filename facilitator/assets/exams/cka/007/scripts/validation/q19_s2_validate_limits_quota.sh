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
NS=cka-q19
CPU=$(kubectl get deploy quota-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
MEM=$(kubectl get deploy quota-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
kubectl get resourcequota compute-quota -n "$NS" >/dev/null 2>&1 || fail "compute-quota was deleted"
[ "$CPU" = "200m" ] || fail "limit cpu is $CPU"
[ "$MEM" = "128Mi" ] || fail "limit memory is $MEM"
pass "resource limits and quota are correct"
