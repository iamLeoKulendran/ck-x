#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="intra-tls"

PORT=$(kubectl -n "$NS" get service orders-svc -o jsonpath='{.spec.ports[0].port}')
TARGET=$(kubectl -n "$NS" get service orders-svc -o jsonpath='{.spec.ports[0].targetPort}')
[ "$PORT" = "443" ] || fail "orders-svc must expose port 443, got $PORT"
[ "$TARGET" = "8443" ] || fail "orders-svc targetPort must be 8443, got $TARGET"

BODY=$(timeout 20 kubectl -n "$NS" exec deploy/payments-client -- curl -ks --max-time 5 https://orders-svc.intra-tls.svc/ 2>/dev/null || true)
echo "$BODY" | grep -q "orders-api: secure" || fail "HTTPS response from orders-svc not received by payments-client"

echo "PASS: HTTPS served through orders-svc and reachable from payments-client"
exit 0
