#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="credential-hygiene"
EXPECTED="S3cr3t-Hunter2-9000"

kubectl -n "$NS" get secret db-creds >/dev/null 2>&1 || fail "Secret 'db-creds' not found in $NS"

VALUE=$(kubectl -n "$NS" get secret db-creds -o jsonpath='{.data.password}' | base64 -d)
[ "$VALUE" = "$EXPECTED" ] || fail "Secret db-creds key 'password' does not hold the migrated credential"

# The plaintext copy must be gone from the ConfigMap (paired with the positive checks above)
if kubectl -n "$NS" get configmap app-config -o jsonpath='{.data.db_password}' 2>/dev/null | grep -q .; then
  fail "ConfigMap app-config still contains the plaintext db_password key"
fi

echo "PASS: credential migrated to a Secret and removed from the ConfigMap"
exit 0
