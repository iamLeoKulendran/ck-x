#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

kubectl get validatingadmissionpolicy trusted-registry-only >/dev/null 2>&1 \
  || fail "ValidatingAdmissionPolicy trusted-registry-only missing"
kubectl get validatingadmissionpolicybinding trusted-registry-only-binding >/dev/null 2>&1 \
  || fail "ValidatingAdmissionPolicyBinding trusted-registry-only-binding missing"

BIND=$(kubectl get validatingadmissionpolicybinding trusted-registry-only-binding -o json)

echo "$BIND" | jq -e '.spec.policyName == "trusted-registry-only"' >/dev/null \
  || fail "binding must reference policy trusted-registry-only"

echo "$BIND" | jq -e '[.spec.validationActions[]] | index("Deny")' >/dev/null \
  || fail "binding validationActions must include Deny"

echo "$BIND" | jq -e '.spec.matchResources.namespaceSelector.matchLabels."registry-policy" == "enforced"' >/dev/null \
  || fail "binding must target namespaces labelled registry-policy=enforced"

echo "PASS: trusted-registry-only policy and Deny binding target registry-policy=enforced"
exit 0
