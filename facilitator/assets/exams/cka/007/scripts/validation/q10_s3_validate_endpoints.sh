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
NS=cka-q10
kubectl rollout status deploy/catalog-web -n "$NS" --timeout=12s >/dev/null 2>&1 || fail "catalog-web not available"
COUNT=$(kubectl get endpoints catalog-web -n "$NS" -o jsonpath='{range .subsets[*].addresses[*]}x{end}' 2>/dev/null | wc -c | tr -d ' ')
[ "$COUNT" -ge 2 ] || fail "ready endpoint count is less than 2"
pass "catalog-web has ready endpoints"
