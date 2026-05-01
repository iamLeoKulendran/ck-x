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
NS=cka-q17
APP=$(kubectl get deploy ha-web -n "$NS" -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.app}' 2>/dev/null)
[ "$APP" = "ha-web" ] || fail "anti-affinity selector app is $APP"
pass "anti-affinity selector is correct"
