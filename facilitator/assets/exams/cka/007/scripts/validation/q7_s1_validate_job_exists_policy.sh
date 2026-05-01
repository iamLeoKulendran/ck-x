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
NS=cka-q07
POLICY=$(kubectl get job checksum-job -n "$NS" -o jsonpath='{.spec.template.spec.restartPolicy}' 2>/dev/null)
[ "$POLICY" = "OnFailure" ] || [ "$POLICY" = "Never" ] || fail "restartPolicy is $POLICY, expected OnFailure or Never"
pass "Job restartPolicy is valid"
