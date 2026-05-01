#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q06
PV=q6-safari-pv
PVC=q6-safari-pvc
kubectl get pv "$PV" >/dev/null 2>&1 || fail "PV $PV not found"
kubectl get pvc "$PVC" -n "$NS" >/dev/null 2>&1 || fail "PVC $PVC not found"
CAP=$(kubectl get pv "$PV" -o jsonpath='{.spec.capacity.storage}')
PATHV=$(kubectl get pv "$PV" -o jsonpath='{.spec.hostPath.path}')
PSTATUS=$(kubectl get pvc "$PVC" -n "$NS" -o jsonpath='{.status.phase}')
BOUND=$(kubectl get pvc "$PVC" -n "$NS" -o jsonpath='{.spec.volumeName}')
[ "$CAP" = "2Gi" ] || fail "PV capacity must be 2Gi"
[ "$PATHV" = "/tmp/exam/q6-data" ] || fail "PV hostPath must be /tmp/exam/q6-data"
[ "$PSTATUS" = "Bound" ] || fail "PVC is not Bound"
[ "$BOUND" = "$PV" ] || fail "PVC is not bound to $PV"
pass "PV and PVC are correct"
