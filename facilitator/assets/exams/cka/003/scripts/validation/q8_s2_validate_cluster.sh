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
EXP=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
GOT=$(kubectl config --kubeconfig="$FILE" view -o jsonpath='{.clusters[?(@.name=="q8-cluster")].cluster.server}' 2>/dev/null)
[ -n "$EXP" ] || fail "Cannot read current cluster server"
[ "$GOT" = "$EXP" ] || fail "q8-cluster server must match current cluster server"
TLS=$(kubectl config --kubeconfig="$FILE" view --raw -o jsonpath='{.clusters[?(@.name=="q8-cluster")].cluster.certificate-authority-data}{.clusters[?(@.name=="q8-cluster")].cluster.insecure-skip-tls-verify}' 2>/dev/null)
[ -n "$TLS" ] || fail "q8-cluster must have certificate-authority-data or insecure-skip-tls-verify"
pass "kubeconfig cluster entry is correct"
