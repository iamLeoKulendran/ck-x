#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="frontend-zone"

kubectl -n "$NS" get networkpolicy allow-trusted-clients >/dev/null 2>&1 \
  || fail "allow-trusted-clients policy missing in $NS"

JSON=$(kubectl -n "$NS" get networkpolicy allow-trusted-clients -o json)

# Selects app=storefront
echo "$JSON" | jq -e '.spec.podSelector.matchLabels.app == "storefront"' >/dev/null \
  || fail "allow-trusted-clients must select pods with label app=storefront"

# Allows ingress from namespaces labelled tier=trusted
echo "$JSON" | jq -e '[.spec.ingress[].from[].namespaceSelector.matchLabels.tier] | index("trusted")' >/dev/null \
  || fail "allow-trusted-clients must allow from namespaceSelector tier=trusted"

# Allows TCP port 80
echo "$JSON" | jq -e '[.spec.ingress[].ports[] | select(.port==80 and (.protocol=="TCP" or .protocol==null))] | length > 0' >/dev/null \
  || fail "allow-trusted-clients must allow TCP port 80"

echo "PASS: allow-trusted-clients admits port 80 from tier=trusted to app=storefront"
exit 0
