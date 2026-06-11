#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="edge-zone"

kubectl -n "$NS" get networkpolicy gateway-egress >/dev/null 2>&1 || fail "gateway-egress policy missing; egress lockdown not in place"

if timeout 20 kubectl -n "$NS" exec deploy/gateway-proxy -- wget -q -T 5 -O /dev/null http://legacy-svc.corp-tools.svc 2>/dev/null; then
  fail "gateway-proxy can still reach legacy-svc.corp-tools; this egress must be blocked"
fi

echo "PASS: non-whitelisted egress to corp-tools is blocked"
exit 0
