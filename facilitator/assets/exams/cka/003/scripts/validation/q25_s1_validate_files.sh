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

CRT=/tmp/exam/q25/tls.crt
KEY=/tmp/exam/q25/tls.key
[ -s "$CRT" ] || fail "tls.crt missing"
[ -s "$KEY" ] || fail "tls.key missing"
openssl x509 -in "$CRT" -noout >/dev/null 2>&1 || fail "tls.crt is not a valid certificate"
openssl rsa -in "$KEY" -check -noout >/dev/null 2>&1 || fail "tls.key is not a valid RSA key"
C1=$(openssl x509 -noout -modulus -in "$CRT" 2>/dev/null | openssl md5)
K1=$(openssl rsa -noout -modulus -in "$KEY" 2>/dev/null | openssl md5)
[ "$C1" = "$K1" ] || fail "certificate and key do not match"
pass "TLS certificate and key are valid"
