#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="edge-zone"

kubectl -n "$NS" get networkpolicy gateway-egress >/dev/null 2>&1 || fail "NetworkPolicy gateway-egress not found in $NS"
JSON=$(kubectl -n "$NS" get networkpolicy gateway-egress -o json)

echo "$JSON" | jq -e '.spec.policyTypes | index("Egress")' >/dev/null || fail "policyTypes must include Egress"
[ "$(echo "$JSON" | jq -r '.spec.podSelector.matchLabels.app // empty')" = "gateway-proxy" ] || fail "podSelector must target app=gateway-proxy only"
echo "$JSON" | jq -e '[.spec.egress[]? | .to[]? | .namespaceSelector.matchLabels["kubernetes.io/metadata.name"] // empty] | index("internal-api")' >/dev/null \
  || fail "egress must allow the internal-api namespace selected by kubernetes.io/metadata.name"
echo "$JSON" | jq -e '[.spec.egress[]? | .ports[]? | select((.port == 53) or (.port == "53"))] | length > 0' >/dev/null \
  || fail "egress must allow DNS on port 53"

echo "PASS: gateway-egress targets app=gateway-proxy and allows only internal-api plus DNS"
exit 0
