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
OUT=$(kubectl get deploy analytics-api -n "$NS" -o jsonpath='{range .spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[*]}{.weight}{":"}{.preference.matchExpressions[0].key}{":"}{.preference.matchExpressions[0].operator}{":"}{.preference.matchExpressions[0].values[0]}{"\n"}{end}' 2>/dev/null | grep 'q15.accelerator:In:gpu')
[ -n "$OUT" ] || fail "preferred affinity for q15.accelerator=gpu missing"
WEIGHT=$(echo "$OUT" | head -n1 | cut -d: -f1)
[ "$WEIGHT" -ge 80 ] || fail "preferred weight $WEIGHT is below 80"
pass "preferred node affinity is correct"
