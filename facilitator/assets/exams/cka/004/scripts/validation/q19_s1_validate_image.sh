#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q19
POD=q19-broken
kubectl get pod "$POD" -n "$NS" >/dev/null 2>&1 || fail "Pod $POD not found"
IMG=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].image}')
[ "$IMG" = "nginx:1.25" ] || fail "Expected image nginx:1.25, got $IMG"
pass "Pod image is fixed"
