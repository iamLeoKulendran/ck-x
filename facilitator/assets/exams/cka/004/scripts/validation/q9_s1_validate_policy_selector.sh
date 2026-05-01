#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q09
NP=q9-egress-lockdown
kubectl get netpol "$NP" -n "$NS" >/dev/null 2>&1 || fail "NetworkPolicy $NP not found"
SEL=$(kubectl get netpol "$NP" -n "$NS" -o jsonpath='{.spec.podSelector.matchLabels.app}')
[ "$SEL" = "backend" ] || fail "NetworkPolicy must select app=backend"
kubectl get netpol "$NP" -n "$NS" -o jsonpath='{.spec.policyTypes[*]}' | grep -qw Egress || fail "policyTypes must include Egress"
pass "NetworkPolicy selector is correct"
