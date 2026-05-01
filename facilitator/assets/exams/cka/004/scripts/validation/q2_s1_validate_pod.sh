#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=default
POD=q2-control-plane-pod
kubectl get pod "$POD" -n "$NS" >/dev/null 2>&1 || fail "Pod $POD not found"
IMG=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].image}')
CNAME=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].name}')
[ "$IMG" = "httpd:2.4-alpine" ] || fail "Expected image httpd:2.4-alpine, got $IMG"
[ "$CNAME" = "web" ] || fail "Expected container name web, got $CNAME"
pass "Pod image and container name are correct"
