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
NS=cka-q17
KEY=$(kubectl get deploy ha-web -n "$NS" -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey}' 2>/dev/null)
[ "$KEY" = "kubernetes.io/hostname" ] || fail "topologyKey is $KEY"
pass "topologyKey is hostname"
