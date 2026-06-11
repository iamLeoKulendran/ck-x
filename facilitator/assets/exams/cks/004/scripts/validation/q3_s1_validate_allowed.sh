#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="audit-team"
SA="system:serviceaccount:audit-team:report-sa"

# Allowed action must still work
kubectl auth can-i get configmaps --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes" \
  || fail "report-sa should be able to get configmaps in $NS"

# Scoped: must NOT be able to read secrets (proves the wildcard was removed)
if kubectl auth can-i get secrets --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes"; then
  fail "report-sa can still get secrets; role is not scoped to configmaps"
fi

echo "PASS: report-sa can get configmaps but not secrets (scoped allow)"
exit 0
