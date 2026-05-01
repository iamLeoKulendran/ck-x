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
NS=cka-q03
SVC=$(kubectl get sts ledger-db -n "$NS" -o jsonpath='{.spec.serviceName}' 2>/dev/null)
[ "$SVC" = "ledger-db-hl" ] || fail "StatefulSet serviceName is $SVC, expected ledger-db-hl"
pass "StatefulSet serviceName is correct"
