#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="audit-team"
SA="system:serviceaccount:audit-team:report-sa"

if kubectl auth can-i delete pods --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes"; then
  fail "report-sa can still delete pods; excessive privilege not removed"
fi

# Positive anchor: it must retain a legitimate configmap read so the SA is still functional
kubectl auth can-i list configmaps --as="$SA" -n "$NS" 2>/dev/null | grep -qx "yes" \
  || fail "report-sa lost configmap access entirely; role over-restricted"

echo "PASS: report-sa cannot delete pods (privilege removed) but retains configmap read"
exit 0
