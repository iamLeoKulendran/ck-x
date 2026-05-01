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
NS=cka-q08
RP=$(kubectl get cronjob db-cleanup -n "$NS" -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}' 2>/dev/null)
[ "$RP" = "OnFailure" ] || [ "$RP" = "Never" ] || fail "restartPolicy is $RP"
pass "CronJob restartPolicy is valid"
