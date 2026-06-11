#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="web-tier"

# Guard: a default-deny policy must exist, otherwise open traffic would pass this test
kubectl -n "$NS" get networkpolicy default-deny >/dev/null 2>&1 || fail "default-deny policy missing; segmentation not in place"

timeout 15 kubectl -n "$NS" exec deploy/web -- wget -q -T 5 -O /dev/null http://api-svc \
  || fail "web cannot reach api-svc on port 80 (this path must be allowed)"

timeout 15 kubectl -n "$NS" exec deploy/api -- wget -q -T 5 -O /dev/null http://cache-svc \
  || fail "api cannot reach cache-svc on port 80 (this path must be allowed)"

echo "PASS: allowed paths web->api and api->cache work"
exit 0
