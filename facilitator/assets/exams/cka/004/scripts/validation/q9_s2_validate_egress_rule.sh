#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q09
NP=q9-egress-lockdown
kubectl get netpol "$NP" -n "$NS" >/dev/null 2>&1 || fail "NetworkPolicy $NP not found"

# Structured jsonpath inspection — guarantees rules are in the egress block, not elsewhere.
EGRESS_TARGETS=$(kubectl get netpol "$NP" -n "$NS" -o jsonpath='{.spec.egress[*].to[*].podSelector.matchLabels.app}' 2>/dev/null || echo "")
echo "$EGRESS_TARGETS" | tr ' ' '\n' | grep -qx 'db' || fail "egress[*].to[*].podSelector must target app=db (got: '$EGRESS_TARGETS')"

EGRESS_PORTS=$(kubectl get netpol "$NP" -n "$NS" -o jsonpath='{.spec.egress[*].ports[*].port}' 2>/dev/null || echo "")
echo "$EGRESS_PORTS" | tr ' ' '\n' | grep -qx '5432' || fail "egress[*].ports[*].port must include 5432 (got: '$EGRESS_PORTS')"

EGRESS_PROTOS=$(kubectl get netpol "$NP" -n "$NS" -o jsonpath='{.spec.egress[*].ports[*].protocol}' 2>/dev/null || echo "")
echo "$EGRESS_PROTOS" | tr ' ' '\n' | grep -qx 'TCP' || fail "egress[*].ports[*].protocol must include TCP (got: '$EGRESS_PROTOS')"

pass "NetworkPolicy egress rule correctly targets app=db on TCP/5432"
