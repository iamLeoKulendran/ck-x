#!/bin/bash
set -euo pipefail
NS="rev1-q05"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get pvc app-data >/dev/null 2>&1 || fail "PVC app-data not found in $NS"
STATUS=$(kubectl -n "$NS" get pvc app-data -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[ "$STATUS" = "Bound" ] || fail "PVC app-data status='$STATUS', expected 'Bound'"
SC=$(kubectl -n "$NS" get pvc app-data -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
[ "$SC" = "local-path" ] || fail "PVC storageClassName='$SC', expected 'local-path'"
pass "PVC app-data is Bound with storageClassName local-path"
