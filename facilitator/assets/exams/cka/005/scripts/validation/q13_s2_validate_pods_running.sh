#!/bin/bash
set -euo pipefail
NS="rev1-q13"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get statefulset cache-cluster >/dev/null 2>&1 || fail "StatefulSet cache-cluster not found"
DESIRED=$(kubectl -n "$NS" get statefulset cache-cluster \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
READY=$(kubectl -n "$NS" get statefulset cache-cluster \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
[ "${READY:-0}" = "${DESIRED:-0}" ] || fail "StatefulSet ready=${READY:-0}, desired=${DESIRED:-0}"
pass "All StatefulSet pods are Running ($READY/$DESIRED)"
