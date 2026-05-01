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
REPL=$(kubectl get deploy frontend-api -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null)
PAUSED=$(kubectl get deploy frontend-api -n "$NS" -o jsonpath='{.spec.paused}' 2>/dev/null)
[ "$REPL" = "3" ] || fail "replicas is $REPL, expected 3"
[ "$PAUSED" != "true" ] || fail "deployment rollout is still paused"
pass "replica count and paused state are correct"
