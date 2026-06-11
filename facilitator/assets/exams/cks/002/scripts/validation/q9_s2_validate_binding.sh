#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

kubectl get validatingadmissionpolicybinding deny-latest-tag-binding >/dev/null 2>&1 \
  || fail "ValidatingAdmissionPolicyBinding 'deny-latest-tag-binding' not found"

JSON=$(kubectl get validatingadmissionpolicybinding deny-latest-tag-binding -o json)

[ "$(echo "$JSON" | jq -r '.spec.policyName')" = "deny-latest-tag" ] \
  || fail "Binding must reference policy deny-latest-tag"

echo "$JSON" | jq -e '.spec.validationActions | index("Deny")' >/dev/null \
  || fail "Binding validationActions must include Deny"

echo "PASS: policy binding is enforcing with Deny action"
exit 0
