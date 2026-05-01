#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q18
DEP=q18-web
kubectl get deploy "$DEP" -n "$NS" >/dev/null 2>&1 || fail "Deployment $DEP not found"
REPL=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.spec.replicas}')
IMG=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}')
LABEL=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.spec.template.metadata.labels.app}')
[ "$REPL" = "3" ] || fail "Expected 3 replicas, got $REPL"
[ "$IMG" = "nginx:1.25" ] || fail "Expected image nginx:1.25, got $IMG"
[ "$LABEL" = "q18-web" ] || fail "Pod template label app=q18-web is required"
pass "Deployment basics are correct"
