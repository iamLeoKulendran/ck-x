#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="supply-frontend"

IMG=$(kubectl -n "$NS" get deployment web-frontend -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null) \
  || fail "web-frontend deployment missing"

PINNED=$(echo "$IMG" | sed -n 's/.*@\(sha256:[0-9a-f]\{64\}\).*/\1/p')
[ -n "$PINNED" ] || fail "could not extract a sha256 digest from the image reference (got: $IMG)"

# Resolve the registry's current digest for ckx/nginx:v1.25 (internal registry, plain HTTP)
ACCEPT="Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json"
ACTUAL=$(curl -s -I -H "$ACCEPT" "http://registry:5000/v2/ckx/nginx/manifests/v1.25" \
          | grep -i docker-content-digest | tr -d '\r' | awk '{print $2}')
[ -n "$ACTUAL" ] || fail "could not resolve the registry digest for ckx/nginx:v1.25"

[ "$PINNED" = "$ACTUAL" ] \
  || fail "pinned digest ($PINNED) does not match the registry digest ($ACTUAL)"

echo "PASS: pinned digest matches the registry digest for ckx/nginx:v1.25"
exit 0
