#!/bin/bash
set -euo pipefail
NS="rev1-q08"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

kubectl -n "$NS" get deployment api-pdb-app >/dev/null 2>&1 \
  || fail "Deployment api-pdb-app not found"

# Anchor on PDB fix — deployment was already available at baseline.
# Without the PDB patch, drain was blocked and this step was never reached.
MIN=$(kubectl -n "$NS" get pdb api-pdb \
  -o jsonpath='{.spec.minAvailable}' 2>/dev/null || echo "")
[ "$MIN" = "1" ] \
  || fail "PDB api-pdb minAvailable='$MIN' — must be patched to 1 before drain/uncordon is meaningful"

AVAILABLE=$(kubectl -n "$NS" get deployment api-pdb-app \
  -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
[ "${AVAILABLE:-0}" -ge 1 ] \
  || fail "Deployment has ${AVAILABLE:-0} available replicas after drain/uncordon, expected >= 1"

pass "PDB patched and Deployment api-pdb-app has ${AVAILABLE} available replica(s)"
