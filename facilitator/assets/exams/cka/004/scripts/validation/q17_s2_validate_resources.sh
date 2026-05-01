#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q17
POD=q17-resource-check
REQCPU=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
REQMEM=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].resources.requests.memory}')
LIMCPU=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
LIMMEM=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].resources.limits.memory}')
[ "$REQCPU" = "100m" ] || fail "CPU request must be 100m"
[ "$REQMEM" = "128Mi" ] || fail "Memory request must be 128Mi"
[ "$LIMCPU" = "250m" ] || fail "CPU limit must be 250m"
[ "$LIMMEM" = "256Mi" ] || fail "Memory limit must be 256Mi"
pass "Resource configuration is correct"
