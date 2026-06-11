#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="web-tier"

if timeout 12 kubectl -n "$NS" exec deploy/web -- wget -q -T 4 -O /dev/null http://cache-svc 2>/dev/null; then
  fail "web can still reach cache-svc; this path must be denied"
fi

if timeout 12 kubectl -n "$NS" exec deploy/cache -- wget -q -T 4 -O /dev/null http://api-svc 2>/dev/null; then
  fail "cache can still reach api-svc; this path must be denied"
fi

echo "PASS: denied paths are blocked"
exit 0
