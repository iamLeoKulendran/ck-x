#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="supply-frontend"

kubectl -n "$NS" get deployment web-frontend >/dev/null 2>&1 || fail "web-frontend deployment missing"
IMG=$(kubectl -n "$NS" get deployment web-frontend -o jsonpath='{.spec.template.spec.containers[0].image}')

echo "$IMG" | grep -q "registry.localhost:5000/ckx/nginx@sha256:" \
  || fail "web-frontend image must be pinned by digest registry.localhost:5000/ckx/nginx@sha256:... (got: $IMG)"

# Must NOT carry a mutable :tag form like :v1.25
if echo "$IMG" | grep -qE ':v1\.25$'; then
  fail "web-frontend still references the mutable tag instead of a digest"
fi

echo "PASS: web-frontend image is digest-pinned"
exit 0
