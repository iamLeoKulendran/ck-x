#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="tls-gateway"

kubectl -n "$NS" get ingress portal-ingress >/dev/null 2>&1 || fail "Ingress 'portal-ingress' not found in $NS"

TLS_HOST=$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.tls[0].hosts[0]}')
[ "$TLS_HOST" = "portal.ckx.local" ] || fail "Ingress TLS host must be portal.ckx.local, got: $TLS_HOST"

TLS_SECRET=$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.tls[0].secretName}')
[ "$TLS_SECRET" = "portal-tls" ] || fail "Ingress TLS secretName must be portal-tls, got: $TLS_SECRET"

echo "PASS: ingress TLS configuration is correct"
exit 0
