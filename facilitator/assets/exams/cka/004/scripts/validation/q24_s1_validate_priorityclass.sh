#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
PC=q24-high-priority
kubectl get priorityclass "$PC" >/dev/null 2>&1 || fail "PriorityClass $PC not found"
VAL=$(kubectl get priorityclass "$PC" -o jsonpath='{.value}')
GD=$(kubectl get priorityclass "$PC" -o jsonpath='{.globalDefault}')
[ "$VAL" = "100000" ] || fail "PriorityClass value must be 100000"
[ "$GD" = "false" ] || fail "globalDefault must be false"
pass "PriorityClass is correct"
