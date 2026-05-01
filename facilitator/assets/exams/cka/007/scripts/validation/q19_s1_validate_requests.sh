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
CPU=$(kubectl get deploy quota-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
MEM=$(kubectl get deploy quota-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
[ "$CPU" = "100m" ] || fail "request cpu is $CPU"
[ "$MEM" = "64Mi" ] || fail "request memory is $MEM"
pass "resource requests are correct"
