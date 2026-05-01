#!/bin/bash
set +e

fail() {
  echo "❌ $1"
  exit 1
}

pass() {
  echo "✅ $1"
  exit 0
}
NS=cka-q01
IMG=$(kubectl get deploy frontend-api -n "$NS" -o jsonpath='{.spec.template.spec.containers[?(@.name=="frontend")].image}' 2>/dev/null)
[ "$IMG" = "nginx:1.27" ] || fail "frontend image is $IMG, expected nginx:1.27"
pass "frontend image is fixed"
