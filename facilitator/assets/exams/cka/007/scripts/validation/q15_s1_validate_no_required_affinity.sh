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
NS=cka-q15
REQ=$(kubectl get deploy analytics-api -n "$NS" -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution}' 2>/dev/null)
[ -z "$REQ" ] || [ "$REQ" = "{}" ] || fail "required node affinity still exists"
pass "required node affinity removed"
