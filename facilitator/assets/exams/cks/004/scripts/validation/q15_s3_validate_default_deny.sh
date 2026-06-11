#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="runtime-soc"

kubectl -n "$NS" get networkpolicy soc-default-deny >/dev/null 2>&1 \
  || fail "soc-default-deny policy missing in $NS"

JSON=$(kubectl -n "$NS" get networkpolicy soc-default-deny -o json)

SEL=$(echo "$JSON" | jq -c '.spec.podSelector')
[ "$SEL" = "{}" ] || fail "soc-default-deny must select all pods (empty podSelector), got: $SEL"

echo "$JSON" | jq -e '[.spec.policyTypes[]] | index("Ingress")' >/dev/null \
  || fail "soc-default-deny must include Ingress in policyTypes"
echo "$JSON" | jq -e '[.spec.policyTypes[]] | index("Egress")' >/dev/null \
  || fail "soc-default-deny must include Egress in policyTypes"

# No allow rules
echo "$JSON" | jq -e '(.spec.ingress // []) | length == 0' >/dev/null \
  || fail "soc-default-deny must not contain ingress allow rules"
echo "$JSON" | jq -e '(.spec.egress // []) | length == 0' >/dev/null \
  || fail "soc-default-deny must not contain egress allow rules"

echo "PASS: soc-default-deny denies all ingress and egress for all pods"
exit 0
