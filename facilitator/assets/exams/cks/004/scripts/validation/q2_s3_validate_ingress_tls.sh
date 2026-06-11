#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="gateway-edge"

kubectl -n "$NS" get ingress portal-ingress >/dev/null 2>&1 || fail "portal-ingress missing in $NS"

JSON=$(kubectl -n "$NS" get ingress portal-ingress -o json)

# TLS block must reference portal-tls and cover host portal.ckx.local
echo "$JSON" | jq -e '[.spec.tls[] | select(.secretName=="portal-tls")] | length > 0' >/dev/null \
  || fail "portal-ingress .spec.tls must reference secret portal-tls"

echo "$JSON" | jq -e '[.spec.tls[] | select(.secretName=="portal-tls") | .hosts[]] | index("portal.ckx.local")' >/dev/null \
  || fail "portal-ingress TLS must cover host portal.ckx.local"

echo "PASS: portal-ingress terminates TLS for portal.ckx.local with portal-tls"
exit 0
