#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="intra-tls"

kubectl -n "$NS" get secret orders-tls >/dev/null 2>&1 || fail "Secret orders-tls not found in $NS"
TYPE=$(kubectl -n "$NS" get secret orders-tls -o jsonpath='{.type}')
[ "$TYPE" = "kubernetes.io/tls" ] || fail "orders-tls must be of type kubernetes.io/tls, got $TYPE"

[ -f /tmp/exam/q9/orders.crt ] || fail "issued certificate /tmp/exam/q9/orders.crt missing (re-run setup)"
WANT=$(sha256sum /tmp/exam/q9/orders.crt | awk '{print $1}')
GOT=$(kubectl -n "$NS" get secret orders-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | sha256sum | awk '{print $1}')
[ "$WANT" = "$GOT" ] || fail "orders-tls tls.crt does not match the issued certificate"

echo "PASS: TLS secret created from the issued certificate"
exit 0
