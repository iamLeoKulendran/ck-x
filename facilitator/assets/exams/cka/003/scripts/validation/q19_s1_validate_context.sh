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

FILE=/tmp/exam/q19/dev.kubeconfig
[ -s "$FILE" ] || fail "dev.kubeconfig missing"
CUR=$(kubectl config --kubeconfig="$FILE" current-context 2>/dev/null)
[ "$CUR" = "dev-context" ] || fail "current-context must be dev-context"
NS=$(kubectl config --kubeconfig="$FILE" view -o jsonpath='{.contexts[?(@.name=="dev-context")].context.namespace}' 2>/dev/null)
USER=$(kubectl config --kubeconfig="$FILE" view -o jsonpath='{.contexts[?(@.name=="dev-context")].context.user}' 2>/dev/null)
CLUSTER=$(kubectl config --kubeconfig="$FILE" view -o jsonpath='{.contexts[?(@.name=="dev-context")].context.cluster}' 2>/dev/null)
[ "$NS" = "rbac-sec-q19" ] || fail "dev-context namespace must be rbac-sec-q19"
[ "$USER" = "dev-token-user" ] || fail "dev-context user must be dev-token-user"
[ "$CLUSTER" = "dev-cluster" ] || fail "dev-context cluster must be dev-cluster"
pass "kubeconfig context is correct"
