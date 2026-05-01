#!/bin/bash
set +e
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NS=rbac-sec-q3
USER="system:serviceaccount:${NS}:deploy-reader"
can_i yes --as="$USER" get deployments.apps -n "$NS" || fail "deploy-reader cannot get deployments.apps"
can_i yes --as="$USER" list deployments.apps -n "$NS" || fail "deploy-reader cannot list deployments.apps"
can_i yes --as="$USER" watch deployments.apps -n "$NS" || fail "deploy-reader cannot watch deployments.apps"
can_i no --as="$USER" delete deployments.apps -n "$NS" || fail "deploy-reader must not delete deployments"
pass "Deployment read permissions are correct"
