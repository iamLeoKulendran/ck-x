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
NS=cka-q20
POL=$(kubectl get priorityclass business-critical -o jsonpath='{.preemptionPolicy}' 2>/dev/null)
PC=$(kubectl get deploy critical-api -n "$NS" -o jsonpath='{.spec.template.spec.priorityClassName}' 2>/dev/null)
[ "$POL" = "PreemptLowerPriority" ] || [ -z "$POL" ] || fail "preemptionPolicy is $POL"
[ "$PC" = "business-critical" ] || fail "deployment priorityClassName is $PC"
pass "preemption policy and deployment usage are correct"
