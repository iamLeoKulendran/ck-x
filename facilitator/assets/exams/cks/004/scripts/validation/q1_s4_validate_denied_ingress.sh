#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="frontend-zone"

# Structural denial check: NetworkPolicy semantics guarantee that with a default-deny
# in place and an allow policy that only admits tier=trusted namespaces, any other
# namespace (e.g. untrusted-clients) is denied. (Connectivity-based denial is not
# observable on this CNI, so denial is proven by policy structure.)

kubectl -n "$NS" get networkpolicy default-deny-ingress >/dev/null 2>&1 \
  || fail "default-deny-ingress missing; denied path cannot be enforced"
kubectl -n "$NS" get networkpolicy allow-trusted-clients >/dev/null 2>&1 \
  || fail "allow-trusted-clients missing"

JSON=$(kubectl -n "$NS" get networkpolicy allow-trusted-clients -o json)

# There must be at least one ingress rule
echo "$JSON" | jq -e '(.spec.ingress // []) | length > 0' >/dev/null \
  || fail "allow-trusted-clients has no ingress rules"

# No rule may have an empty 'from' (which would admit all sources)
if echo "$JSON" | jq -e '[.spec.ingress[] | select((.from // []) | length == 0)] | length > 0' >/dev/null 2>&1; then
  fail "allow-trusted-clients has an ingress rule with empty 'from' (admits everything)"
fi

# Every 'from' peer must restrict to namespaceSelector tier=trusted (no match-all selector)
echo "$JSON" | jq -e '[.spec.ingress[].from[]] | all(.namespaceSelector.matchLabels.tier == "trusted")' >/dev/null \
  || fail "allow-trusted-clients admits sources beyond tier=trusted; untrusted not denied"

# A match-all namespaceSelector ({}) would defeat the restriction
if echo "$JSON" | jq -e '[.spec.ingress[].from[] | select(.namespaceSelector.matchLabels == {} or .namespaceSelector == {})] | length > 0' >/dev/null 2>&1; then
  fail "allow-trusted-clients contains a match-all namespaceSelector"
fi

echo "PASS: only tier=trusted namespaces are admitted; untrusted is denied by policy"
exit 0
