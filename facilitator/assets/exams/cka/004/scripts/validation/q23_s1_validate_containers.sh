#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q23
POD=q23-logger
kubectl get pod "$POD" -n "$NS" >/dev/null 2>&1 || fail "Pod $POD not found"
NAMES=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[*].name}')
echo "$NAMES" | grep -qw writer || fail "Missing writer container"
echo "$NAMES" | grep -qw reader || fail "Missing reader container"
IMAGES=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[*].image}')
[ "$(echo "$IMAGES" | grep -o 'busybox:1.36' | wc -l | tr -d ' ')" -ge 2 ] || fail "Both containers must use busybox:1.36"
pass "Containers are correct"
