#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

kubectl get validatingadmissionpolicy deny-hostpath >/dev/null 2>&1 || fail "ValidatingAdmissionPolicy deny-hostpath not found"
VAP=$(kubectl get validatingadmissionpolicy deny-hostpath -o json)

echo "$VAP" | jq -e '[.spec.matchConstraints.resourceRules[]?.resources[]?] | index("pods")' >/dev/null \
  || fail "policy must match pods"
echo "$VAP" | jq -e '[.spec.validations[]?.expression] | map(select(contains("hostPath"))) | length > 0' >/dev/null \
  || fail "policy expression must reject hostPath volumes"

kubectl get validatingadmissionpolicybinding deny-hostpath-binding >/dev/null 2>&1 || fail "ValidatingAdmissionPolicyBinding deny-hostpath-binding not found"
VAPB=$(kubectl get validatingadmissionpolicybinding deny-hostpath-binding -o json)
[ "$(echo "$VAPB" | jq -r '.spec.policyName')" = "deny-hostpath" ] || fail "binding must reference deny-hostpath"
echo "$VAPB" | jq -e '.spec.validationActions | index("Deny")' >/dev/null || fail "binding validationActions must include Deny"
[ "$(echo "$VAPB" | jq -r '.spec.matchResources.namespaceSelector.matchLabels["volume-policy"] // empty')" = "restricted" ] \
  || fail "binding must select namespaces labeled volume-policy=restricted"

echo "PASS: admission policy and binding correctly target restricted namespaces"
exit 0
