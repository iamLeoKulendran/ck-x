#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="support-rbac"
SA="system:serviceaccount:support-rbac:oncall-sa"

if kubectl auth can-i create pods/exec --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes"; then
  fail "oncall-sa can still create pods/exec; exec privilege not removed"
fi

# Positive anchor: it must still be able to read pods (functional, not stripped to nothing)
kubectl auth can-i get pods --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes" \
  || fail "oncall-sa lost pod read access; role over-restricted"

echo "PASS: oncall-sa cannot exec into pods but retains pod read"
exit 0
