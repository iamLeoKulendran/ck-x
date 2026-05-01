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
kubectl wait --for=condition=complete job/checksum-job -n "$NS" --timeout=15s >/dev/null 2>&1 || fail "checksum-job did not complete"
SUCCEEDED=$(kubectl get job checksum-job -n "$NS" -o jsonpath='{.status.succeeded}' 2>/dev/null)
[ "$SUCCEEDED" = "1" ] || fail "succeeded count is $SUCCEEDED, expected 1"
pass "checksum-job completed"
