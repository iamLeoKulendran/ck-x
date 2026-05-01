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

KEY=/tmp/exam/q21/q21-kubelet-serving.key
CSR=/tmp/exam/q21/q21-kubelet-serving.csr
[ -s "$KEY" ] || fail "Private key missing"
[ -s "$CSR" ] || fail "CSR file missing"
openssl req -in "$CSR" -noout -subject >/dev/null 2>&1 || fail "CSR file is not valid"
pass "Kubelet serving key and CSR files exist"
