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

NS=rbac-sec-q6
USER="system:serviceaccount:${NS}:node-inspector"
can_i yes --as="$USER" get nodes || fail "node-inspector cannot get nodes"
can_i yes --as="$USER" list nodes || fail "node-inspector cannot list nodes"
can_i no --as="$USER" delete nodes || fail "node-inspector must not delete nodes"
pass "Node read permissions are correct"
