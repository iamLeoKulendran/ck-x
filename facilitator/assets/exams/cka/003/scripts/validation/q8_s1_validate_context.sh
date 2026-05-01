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

FILE=/tmp/exam/q8/kubeconfig
[ -s "$FILE" ] || fail "kubeconfig file missing"
CUR=$(kubectl config --kubeconfig="$FILE" current-context 2>/dev/null)
[ "$CUR" = "q8-context" ] || fail "current-context must be q8-context"
NS=$(kubectl config --kubeconfig="$FILE" view -o jsonpath='{.contexts[?(@.name=="q8-context")].context.namespace}' 2>/dev/null)
USR=$(kubectl config --kubeconfig="$FILE" view -o jsonpath='{.contexts[?(@.name=="q8-context")].context.user}' 2>/dev/null)
CLS=$(kubectl config --kubeconfig="$FILE" view -o jsonpath='{.contexts[?(@.name=="q8-context")].context.cluster}' 2>/dev/null)
[ "$NS" = "rbac-sec-q8" ] || fail "q8-context namespace must be rbac-sec-q8"
[ "$USR" = "q8-user" ] || fail "q8-context user must be q8-user"
[ "$CLS" = "q8-cluster" ] || fail "q8-context cluster must be q8-cluster"
pass "kubeconfig context is correct"
