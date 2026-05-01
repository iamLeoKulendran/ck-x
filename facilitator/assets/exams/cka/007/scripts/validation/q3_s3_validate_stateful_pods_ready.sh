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
READY=$(kubectl get sts ledger-db -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$READY" = "2" ] || fail "readyReplicas is $READY, expected 2"
kubectl get pod ledger-db-0 -n "$NS" >/dev/null 2>&1 || fail "ledger-db-0 missing"
kubectl get pod ledger-db-1 -n "$NS" >/dev/null 2>&1 || fail "ledger-db-1 missing"
pass "StatefulSet pods are ready with stable names"
