#!/bin/bash
set -euo pipefail
NS="rev1-q09"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
IMAGE=$(kubectl -n "$NS" get daemonset log-collector \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
[[ "$IMAGE" == *"nginx:1.28"* ]] || fail "DaemonSet image='$IMAGE', expected nginx:1.28"
DESIRED=$(kubectl -n "$NS" get daemonset log-collector \
  -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
READY=$(kubectl -n "$NS" get daemonset log-collector \
  -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
[ "${READY:-0}" = "${DESIRED:-0}" ] || fail "DaemonSet ready=${READY:-0}, desired=${DESIRED:-0}"
pass "All DaemonSet pods running nginx:1.28 ($READY/$DESIRED ready)"
