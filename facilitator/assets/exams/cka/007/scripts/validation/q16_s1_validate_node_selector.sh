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
SEL=$(kubectl get deploy reserved-api -n "$NS" -o jsonpath='{.spec.template.spec.nodeSelector.q16\.pool}' 2>/dev/null)
[ "$SEL" = "reserved" ] || fail "nodeSelector q16.pool is $SEL"
pass "reserved nodeSelector exists"
