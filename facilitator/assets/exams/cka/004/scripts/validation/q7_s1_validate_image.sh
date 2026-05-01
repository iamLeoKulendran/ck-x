#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q07
DEP=q7-broken-web
IMG=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMG" = "nginx:1.25" ] || fail "Expected image nginx:1.25, got $IMG"
pass "Deployment image is restored"
