#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="payments-svc"

kubectl -n "$NS" get deployment billing >/dev/null 2>&1 || fail "billing deployment missing"
JSON=$(kubectl -n "$NS" get deployment billing -o json)

# DB_PASSWORD must come from a secretKeyRef on the billing-db secret
echo "$JSON" | jq -e '
  [.spec.template.spec.containers[].env[]?
   | select(.name=="DB_PASSWORD")
   | select(.valueFrom.secretKeyRef.name=="billing-db" and .valueFrom.secretKeyRef.key=="password")]
  | length > 0' >/dev/null \
  || fail "DB_PASSWORD must be sourced from secretKeyRef billing-db/password"

# No plaintext password literal may remain anywhere in the pod spec
if echo "$JSON" | jq -r '.spec.template.spec' | grep -qF 'S3cr3t-P@ss!'; then
  fail "plaintext password value still present in the pod spec"
fi

# No env entry named DB_PASSWORD may carry a literal value
if echo "$JSON" | jq -e '[.spec.template.spec.containers[].env[]? | select(.name=="DB_PASSWORD") | select(.value != null)] | length > 0' >/dev/null 2>&1; then
  fail "DB_PASSWORD still uses a literal value field"
fi

echo "PASS: DB_PASSWORD sourced from secret; no plaintext remains"
exit 0
