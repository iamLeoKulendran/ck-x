#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q19
POD=q19-broken
kubectl get pod "$POD" -n "$NS" >/dev/null 2>&1 || fail "Pod $POD not found"
RUNNING=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.containerStatuses[0].state.running.startedAt}' 2>/dev/null || echo "")
[ -n "$RUNNING" ] || fail "Container is not in running state (state.running missing). Pod must be Running, not Waiting/Terminated"
RESTARTS=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
[ "${RESTARTS:-0}" -lt 3 ] 2>/dev/null || fail "Container restartCount is $RESTARTS, expected < 3 (image fix is one-shot — high restart count suggests Pod was not recreated)"
pass "Container is running (started $RUNNING) with $RESTARTS restarts"
