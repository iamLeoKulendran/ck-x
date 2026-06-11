#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="tls-gateway"

kubectl -n "$NS" get secret portal-tls >/dev/null 2>&1 || fail "Secret 'portal-tls' not found in $NS"

TYPE=$(kubectl -n "$NS" get secret portal-tls -o jsonpath='{.type}')
[ "$TYPE" = "kubernetes.io/tls" ] || fail "Secret type must be kubernetes.io/tls, got: $TYPE"

[ -f /tmp/exam/q2/portal.crt ] || fail "Planted certificate /tmp/exam/q2/portal.crt missing (rerun setup)"

kubectl -n "$NS" get secret portal-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/q2_check.crt
if ! diff -q /tmp/q2_check.crt /tmp/exam/q2/portal.crt >/dev/null 2>&1; then
  rm -f /tmp/q2_check.crt
  fail "Secret tls.crt does not match the provided /tmp/exam/q2/portal.crt"
fi
rm -f /tmp/q2_check.crt

echo "PASS: portal-tls secret holds the provided certificate"
exit 0
