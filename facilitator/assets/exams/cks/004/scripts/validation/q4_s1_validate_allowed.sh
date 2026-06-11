#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="support-rbac"
SA="system:serviceaccount:support-rbac:oncall-sa"

kubectl auth can-i get pods --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes" \
  || fail "oncall-sa should be able to get pods in $NS"

kubectl auth can-i get pods/log --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes" \
  || fail "oncall-sa should be able to get pods/log in $NS"

# Scoped: the over-broad create verb must have been removed (no create on pods)
if kubectl auth can-i create pods --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes"; then
  fail "oncall-sa can still create pods; role not scoped to read-only"
fi

echo "PASS: oncall-sa can read pods and pod logs but cannot create pods"
exit 0
