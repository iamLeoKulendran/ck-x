#!/bin/bash
set -euo pipefail
NS="rev1-q08"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get pdb api-pdb >/dev/null 2>&1 || fail "PodDisruptionBudget api-pdb not found in $NS"
MIN=$(kubectl -n "$NS" get pdb api-pdb -o jsonpath='{.spec.minAvailable}' 2>/dev/null || echo "")
[ "$MIN" = "1" ] || fail "PDB minAvailable='$MIN', expected '1'"
pass "PDB api-pdb minAvailable is 1"
