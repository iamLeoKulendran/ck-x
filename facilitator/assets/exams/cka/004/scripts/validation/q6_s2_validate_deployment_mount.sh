#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q06
DEP=q6-safari
kubectl get deploy "$DEP" -n "$NS" >/dev/null 2>&1 || fail "Deployment $DEP not found"
IMG=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMG" = "httpd:2.4-alpine" ] || fail "Deployment image must be httpd:2.4-alpine"
kubectl get deploy "$DEP" -n "$NS" -o yaml | grep -q 'claimName: q6-safari-pvc' || fail "Deployment must use PVC q6-safari-pvc"
kubectl get deploy "$DEP" -n "$NS" -o yaml | grep -q 'mountPath: /tmp/safari-data' || fail "Deployment must mount PVC at /tmp/safari-data"
pass "Deployment volume mount is correct"
