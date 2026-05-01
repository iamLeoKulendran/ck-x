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
NS=cka-q17
kubectl rollout status deploy/ha-web -n "$NS" --timeout=30s >/dev/null 2>&1 || fail "ha-web not available"
NODES=$(kubectl get pods -n "$NS" -l app=ha-web -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l | tr -d ' ')
[ "$NODES" -ge 2 ] || fail "ha-web pods are not spread across at least two nodes"
pass "ha-web replicas are on different nodes"
