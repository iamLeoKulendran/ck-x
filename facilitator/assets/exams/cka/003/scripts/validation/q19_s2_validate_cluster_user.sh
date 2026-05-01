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
EXP=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
GOT=$(kubectl config --kubeconfig="$FILE" view -o jsonpath='{.clusters[?(@.name=="dev-cluster")].cluster.server}' 2>/dev/null)
TOKEN=$(kubectl config --kubeconfig="$FILE" view --raw -o jsonpath='{.users[?(@.name=="dev-token-user")].user.token}' 2>/dev/null)
[ "$GOT" = "$EXP" ] || fail "dev-cluster server must match current cluster"
[ "$TOKEN" = "dev-token-123" ] || fail "dev-token-user token must be dev-token-123"
pass "kubeconfig cluster and user are correct"
