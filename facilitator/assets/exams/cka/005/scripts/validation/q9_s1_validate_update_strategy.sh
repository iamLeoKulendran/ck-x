#!/bin/bash
set -euo pipefail
NS="rev1-q09"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get daemonset log-collector >/dev/null 2>&1 || fail "DaemonSet log-collector not found"
TYPE=$(kubectl -n "$NS" get daemonset log-collector \
  -o jsonpath='{.spec.updateStrategy.type}' 2>/dev/null || echo "")
[ "$TYPE" = "RollingUpdate" ] || fail "updateStrategy.type='$TYPE', expected 'RollingUpdate'"
MAX=$(kubectl -n "$NS" get daemonset log-collector \
  -o jsonpath='{.spec.updateStrategy.rollingUpdate.maxUnavailable}' 2>/dev/null || echo "")
[ "$MAX" = "1" ] || fail "maxUnavailable='$MAX', expected '1'"
pass "DaemonSet log-collector uses RollingUpdate with maxUnavailable=1"
