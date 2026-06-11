#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="checkout"

TARGET=$(kubectl -n "$NS" get service checkout-svc -o jsonpath='{.spec.ports[0].targetPort}')
[ "$TARGET" = "8080" ] || fail "checkout-svc targetPort must be 8080, got $TARGET"
PORT=$(kubectl -n "$NS" get service checkout-svc -o jsonpath='{.spec.ports[0].port}')
[ "$PORT" = "80" ] || fail "checkout-svc port must stay 80, got $PORT"

timeout 20 kubectl -n "$NS" exec deploy/storefront-client -- wget -q -T 5 -O /dev/null http://checkout-svc.checkout.svc \
  || fail "checkout-svc does not answer HTTP requests from inside the namespace"

echo "PASS: checkout-svc routes to 8080 and serves traffic"
exit 0
