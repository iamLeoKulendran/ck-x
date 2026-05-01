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
NS=cka-q18
APP=$(kubectl get deploy pay-api -n "$NS" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].labelSelector.matchLabels.app}' 2>/dev/null)
[ "$APP" = "pay-api" ] || fail "spread selector app is $APP"
pass "spread selector matches pod labels"
