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
CLUSTER_IP=$(kubectl get svc ledger-db-hl -n "$NS" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
SEL=$(kubectl get svc ledger-db-hl -n "$NS" -o jsonpath='{.spec.selector.app}' 2>/dev/null)
[ "$CLUSTER_IP" = "None" ] || fail "ledger-db-hl clusterIP is $CLUSTER_IP, expected None"
[ "$SEL" = "ledger-db" ] || fail "ledger-db-hl selector app is $SEL"
pass "headless service is correct"
