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
NS=cka-q06
SEL=$(kubectl get ds packet-capture -n "$NS" -o jsonpath='{.spec.template.spec.nodeSelector.q06\.capture}' 2>/dev/null)
[ "$SEL" = "true" ] || fail "nodeSelector q06.capture is $SEL, expected true"
pass "DaemonSet nodeSelector is correct"
