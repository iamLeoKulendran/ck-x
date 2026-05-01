#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q24
POD=q24-important
kubectl get pod "$POD" -n "$NS" >/dev/null 2>&1 || fail "Pod $POD not found"
PC=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.priorityClassName}')
IMG=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].image}')
[ "$PC" = "q24-high-priority" ] || fail "Pod priorityClassName must be q24-high-priority"
[ "$IMG" = "nginx:1.25" ] || fail "Pod image must be nginx:1.25"
pass "Pod priority configuration is correct"
