#!/bin/bash
set -euo pipefail
NS="rev1-q10"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get networkpolicy api-policy >/dev/null 2>&1 || fail "NetworkPolicy api-policy not found in $NS"
SELECTOR=$(kubectl -n "$NS" get networkpolicy api-policy \
  -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null || echo "")
[ "$SELECTOR" = "api" ] || fail "podSelector app='$SELECTOR', expected 'api'"
POLICY_TYPES=$(kubectl -n "$NS" get networkpolicy api-policy \
  -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null || echo "")
[[ "$POLICY_TYPES" == *"Ingress"* ]] || fail "policyTypes missing 'Ingress'"
[[ "$POLICY_TYPES" == *"Egress"* ]] || fail "policyTypes missing 'Egress'"
pass "NetworkPolicy api-policy exists with correct podSelector and policyTypes"
