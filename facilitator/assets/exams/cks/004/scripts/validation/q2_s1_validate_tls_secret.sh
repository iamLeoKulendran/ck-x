#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="gateway-edge"

kubectl -n "$NS" get secret portal-tls >/dev/null 2>&1 || fail "portal-tls secret missing in $NS"

TYPE=$(kubectl -n "$NS" get secret portal-tls -o jsonpath='{.type}')
[ "$TYPE" = "kubernetes.io/tls" ] || fail "portal-tls must be type kubernetes.io/tls, got: $TYPE"

CRT=$(kubectl -n "$NS" get secret portal-tls -o jsonpath='{.data.tls\.crt}')
KEY=$(kubectl -n "$NS" get secret portal-tls -o jsonpath='{.data.tls\.key}')
[ -n "$CRT" ] || fail "portal-tls is missing tls.crt"
[ -n "$KEY" ] || fail "portal-tls is missing tls.key"

# Certificate must be valid PEM and carry the expected CN
echo "$CRT" | base64 -d | openssl x509 -noout -subject 2>/dev/null | grep -q "portal.ckx.local" \
  || fail "portal-tls certificate does not carry CN portal.ckx.local"

echo "PASS: portal-tls is a valid kubernetes.io/tls secret for portal.ckx.local"
exit 0
