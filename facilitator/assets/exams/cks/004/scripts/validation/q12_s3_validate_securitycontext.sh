#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="supply-scan"

kubectl -n "$NS" get deployment scanner-api >/dev/null 2>&1 || fail "scanner-api deployment missing"
SC=$(kubectl -n "$NS" get deployment scanner-api -o json | jq '.spec.template.spec.containers[0].securityContext')

# privileged must be absent or false
echo "$SC" | jq -e '(.privileged // false) == false' >/dev/null \
  || fail "scanner-api must not run privileged"
echo "$SC" | jq -e '.allowPrivilegeEscalation == false' >/dev/null \
  || fail "scanner-api must set allowPrivilegeEscalation: false"
echo "$SC" | jq -e '.capabilities.drop | index("ALL")' >/dev/null \
  || fail "scanner-api must drop ALL capabilities"

RNR_CON=$(echo "$SC" | jq -r '.runAsNonRoot // empty')
RNR_POD=$(kubectl -n "$NS" get deployment scanner-api -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}')
[ "$RNR_CON" = "true" ] || [ "$RNR_POD" = "true" ] \
  || fail "scanner-api must set runAsNonRoot: true"

echo "PASS: scanner-api security context is hardened"
exit 0
