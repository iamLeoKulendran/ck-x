#!/bin/bash
set -euo pipefail
NS="rev1-q13"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get statefulset cache-cluster >/dev/null 2>&1 || fail "StatefulSet cache-cluster not found"
SC=$(kubectl -n "$NS" get statefulset cache-cluster \
  -o jsonpath='{.spec.volumeClaimTemplates[0].spec.storageClassName}' 2>/dev/null || echo "")
[ "$SC" = "standard" ] || fail "volumeClaimTemplate storageClassName='$SC', expected 'standard'"
pass "StatefulSet cache-cluster uses storageClassName 'standard' in volumeClaimTemplates"
