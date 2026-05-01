#!/bin/bash
set +e

fail() {
  echo "❌ $1"
  exit 1
}

pass() {
  echo "✅ $1"
  exit 0
}
NS=cka-q04
kubectl get pvc data-metrics-store-0 -n "$NS" >/dev/null 2>&1 || fail "data-metrics-store-0 PVC missing"
kubectl get pvc data-metrics-store-1 -n "$NS" >/dev/null 2>&1 || fail "data-metrics-store-1 PVC missing"
READY=$(kubectl get sts metrics-store -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$READY" = "2" ] || fail "readyReplicas is $READY, expected 2"
pass "StatefulSet PVCs and pods are ready"
