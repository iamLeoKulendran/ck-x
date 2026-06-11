#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="txn-mesh"

# Structural denial check: with an Egress policy in place, NetworkPolicy semantics deny
# any egress not explicitly allowed. Verify that port-80 egress is restricted to
# tier=ledger only, so egress to txn-public (not tier=ledger) is denied by policy.
# (Connectivity-based denial is not observable on this CNI.)

kubectl -n "$NS" get networkpolicy processor-egress >/dev/null 2>&1 \
  || fail "processor-egress missing; denied path cannot be enforced"

JSON=$(kubectl -n "$NS" get networkpolicy processor-egress -o json)

echo "$JSON" | jq -e '[.spec.policyTypes[]] | index("Egress")' >/dev/null \
  || fail "processor-egress must be an Egress policy (default-deny egress)"

# Any egress rule that permits TCP 80 must restrict its destination to tier=ledger.
# Fail if a port-80 rule has empty 'to' (allows all) or a non-tier=ledger destination.
if echo "$JSON" | jq -e '
  [.spec.egress[]
   | select((.ports // []) | any(.port == 80))
   | select(((.to // []) | length == 0)
            or (any(.to[]; .namespaceSelector.matchLabels.tier != "ledger")))]
  | length > 0' >/dev/null 2>&1; then
  fail "processor-egress allows port 80 beyond tier=ledger; egress to txn-public not denied"
fi

# And there must be a port-80 rule that does target tier=ledger (the allowed path)
echo "$JSON" | jq -e '
  [.spec.egress[]
   | select((.ports // []) | any(.port == 80))
   | .to[]?.namespaceSelector.matchLabels.tier] | index("ledger")' >/dev/null \
  || fail "processor-egress does not scope port 80 to tier=ledger"

echo "PASS: port-80 egress is scoped to tier=ledger; txn-public denied by policy"
exit 0
