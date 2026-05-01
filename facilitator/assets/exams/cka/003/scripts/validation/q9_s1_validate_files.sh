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

KEY=/tmp/exam/q9/q9-user.key
CSR=/tmp/exam/q9/q9-user.csr
[ -s "$KEY" ] || fail "Private key missing"
[ -s "$CSR" ] || fail "CSR file missing"
openssl req -in "$CSR" -noout -subject 2>/dev/null | grep -q 'CN *= *q9-user\|CN=q9-user' || fail "CSR subject must include CN=q9-user"
pass "Client key and CSR file are correct"
