#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="gateway-edge"

kubectl -n "$NS" get ingress portal-ingress >/dev/null 2>&1 || fail "portal-ingress missing in $NS"

JSON=$(kubectl -n "$NS" get ingress portal-ingress -o json)

# Rule for host portal.ckx.local
echo "$JSON" | jq -e '[.spec.rules[] | select(.host=="portal.ckx.local")] | length > 0' >/dev/null \
  || fail "portal-ingress must define a rule for host portal.ckx.local"

# Path / with pathType Prefix backed by portal-svc:80
echo "$JSON" | jq -e '
  [.spec.rules[] | select(.host=="portal.ckx.local") | .http.paths[]
   | select(.path=="/" and .pathType=="Prefix"
            and .backend.service.name=="portal-svc"
            and .backend.service.port.number==80)] | length > 0' >/dev/null \
  || fail "portal-ingress must route host portal.ckx.local path / (Prefix) to portal-svc:80"

echo "PASS: portal-ingress routes portal.ckx.local to portal-svc:80"
exit 0
