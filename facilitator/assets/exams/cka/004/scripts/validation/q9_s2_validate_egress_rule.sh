#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q09
NP=q9-egress-lockdown
YAML=$(kubectl get netpol "$NP" -n "$NS" -o yaml)
echo "$YAML" | grep -q 'app: db' || fail "Missing destination podSelector app=db"
echo "$YAML" | grep -q 'port: 5432' || fail "Missing egress port 5432"
echo "$YAML" | grep -q 'protocol: TCP' || fail "Missing TCP protocol"
pass "NetworkPolicy egress rule is correct"
