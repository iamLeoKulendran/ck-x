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

FILE=/tmp/exam/q10/cert-expiration.txt
[ -s "$FILE" ] || fail "Certificate expiration report missing or empty"
grep -Eiq 'certificate|expires|expiration|residual' "$FILE" || fail "Report does not look like kubeadm certificate output"
pass "Certificate expiration report exists"
