#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="web-tier"

kubectl -n "$NS" get networkpolicy default-deny >/dev/null 2>&1 || fail "NetworkPolicy 'default-deny' not found in $NS"

POD_SELECTOR=$(kubectl -n "$NS" get networkpolicy default-deny -o jsonpath='{.spec.podSelector}')
[ "$POD_SELECTOR" = "{}" ] || fail "default-deny podSelector must be empty ({}) to select all pods, got: $POD_SELECTOR"

TYPES=$(kubectl -n "$NS" get networkpolicy default-deny -o jsonpath='{.spec.policyTypes}')
echo "$TYPES" | grep -q "Ingress" || fail "default-deny policyTypes must include Ingress"
echo "$TYPES" | grep -q "Egress" || fail "default-deny policyTypes must include Egress"

INGRESS=$(kubectl -n "$NS" get networkpolicy default-deny -o jsonpath='{.spec.ingress}')
EGRESS=$(kubectl -n "$NS" get networkpolicy default-deny -o jsonpath='{.spec.egress}')
[ -z "$INGRESS" ] || fail "default-deny must not contain ingress allow rules"
[ -z "$EGRESS" ] || fail "default-deny must not contain egress allow rules"

echo "PASS: default-deny policy is correctly configured"
exit 0
