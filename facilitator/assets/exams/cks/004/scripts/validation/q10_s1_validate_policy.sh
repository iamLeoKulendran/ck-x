#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="txn-mesh"

kubectl -n "$NS" get networkpolicy processor-egress >/dev/null 2>&1 \
  || fail "processor-egress policy missing in $NS"

JSON=$(kubectl -n "$NS" get networkpolicy processor-egress -o json)

echo "$JSON" | jq -e '.spec.podSelector.matchLabels.app == "processor"' >/dev/null \
  || fail "processor-egress must select pods with label app=processor"

echo "$JSON" | jq -e '[.spec.policyTypes[]] | index("Egress")' >/dev/null \
  || fail "processor-egress must include Egress in policyTypes"

# Must permit DNS (port 53)
echo "$JSON" | jq -e '[.spec.egress[].ports[]? | select(.port==53)] | length > 0' >/dev/null \
  || fail "processor-egress must allow DNS (port 53)"

# Must permit TCP 80 to tier=ledger namespaces
echo "$JSON" | jq -e '
  [.spec.egress[]
   | select((.ports // []) | any(.port==80))
   | .to[]?.namespaceSelector.matchLabels.tier] | index("ledger")' >/dev/null \
  || fail "processor-egress must allow TCP 80 to namespaceSelector tier=ledger"

echo "PASS: processor-egress permits DNS and TCP 80 to tier=ledger only"
exit 0
