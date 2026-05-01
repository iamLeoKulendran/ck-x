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
NS=cka-q14
SEL=$(kubectl get deploy reporting-api -n "$NS" -o jsonpath='{.spec.template.spec.nodeSelector.q14\.disk}' 2>/dev/null)
[ "$SEL" = "ssd" ] || fail "nodeSelector q14.disk is $SEL"
pass "nodeSelector is correct"
