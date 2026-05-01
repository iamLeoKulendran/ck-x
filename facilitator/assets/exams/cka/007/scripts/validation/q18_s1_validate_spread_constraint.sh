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
NS=cka-q18
KEY=$(kubectl get deploy pay-api -n "$NS" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].topologyKey}' 2>/dev/null)
SKEW=$(kubectl get deploy pay-api -n "$NS" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].maxSkew}' 2>/dev/null)
UNSAT=$(kubectl get deploy pay-api -n "$NS" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].whenUnsatisfiable}' 2>/dev/null)
[ "$KEY" = "kubernetes.io/hostname" ] || fail "topologyKey is $KEY"
[ "$SKEW" = "1" ] || fail "maxSkew is $SKEW"
[ "$UNSAT" = "DoNotSchedule" ] || fail "whenUnsatisfiable is $UNSAT"
pass "spread constraint fields are correct"
