#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

kubectl get validatingadmissionpolicy deny-latest-tag >/dev/null 2>&1 \
  || fail "ValidatingAdmissionPolicy 'deny-latest-tag' not found"

JSON=$(kubectl get validatingadmissionpolicy deny-latest-tag -o json)

echo "$JSON" | jq -e '.spec.validations[] | select(.expression | test("latest"))' >/dev/null \
  || fail "Policy must contain a CEL expression rejecting the latest tag"

echo "$JSON" | jq -e '.spec.matchConstraints.resourceRules[] | select(.resources | index("deployments"))' >/dev/null \
  || fail "Policy matchConstraints must target deployments"

echo "PASS: deny-latest-tag policy exists with a latest-tag CEL rule"
exit 0
