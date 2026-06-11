#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="frontend-zone"

kubectl -n "$NS" get networkpolicy default-deny-ingress >/dev/null 2>&1 \
  || fail "default-deny-ingress policy missing in $NS"

# Must select all pods (empty podSelector) and include Ingress in policyTypes
SEL=$(kubectl -n "$NS" get networkpolicy default-deny-ingress -o jsonpath='{.spec.podSelector}')
[ "$SEL" = "{}" ] || fail "default-deny-ingress must select all pods (empty podSelector), got: $SEL"

kubectl -n "$NS" get networkpolicy default-deny-ingress -o jsonpath='{.spec.policyTypes}' \
  | grep -q "Ingress" || fail "default-deny-ingress must list Ingress in policyTypes"

# A default-deny has no ingress allow rules
RULES=$(kubectl -n "$NS" get networkpolicy default-deny-ingress -o jsonpath='{.spec.ingress}')
[ -z "$RULES" ] || [ "$RULES" = "[]" ] || fail "default-deny-ingress must not contain ingress allow rules"

echo "PASS: default-deny-ingress denies all ingress for all pods"
exit 0
