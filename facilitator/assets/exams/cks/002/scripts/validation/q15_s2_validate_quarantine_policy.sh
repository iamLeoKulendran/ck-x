#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="incident-response"

kubectl -n "$NS" get networkpolicy quarantine >/dev/null 2>&1 || fail "NetworkPolicy 'quarantine' not found in $NS"

JSON=$(kubectl -n "$NS" get networkpolicy quarantine -o json)

SELECTOR=$(echo "$JSON" | jq -r '.spec.podSelector.matchLabels.app // empty')
[ "$SELECTOR" = "kernel-helper" ] || fail "quarantine policy must select pods with app=kernel-helper, got: ${SELECTOR:-all pods}"

echo "$JSON" | jq -e '.spec.policyTypes | index("Ingress")' >/dev/null || fail "quarantine policy must include Ingress in policyTypes"
echo "$JSON" | jq -e '.spec.policyTypes | index("Egress")' >/dev/null || fail "quarantine policy must include Egress in policyTypes"

INGRESS=$(echo "$JSON" | jq -r '.spec.ingress // empty')
EGRESS=$(echo "$JSON" | jq -r '.spec.egress // empty')
[ -z "$INGRESS" ] || fail "quarantine policy must not contain ingress allow rules"
[ -z "$EGRESS" ] || fail "quarantine policy must not contain egress allow rules"

echo "PASS: kernel-helper is fully quarantined by NetworkPolicy"
exit 0
