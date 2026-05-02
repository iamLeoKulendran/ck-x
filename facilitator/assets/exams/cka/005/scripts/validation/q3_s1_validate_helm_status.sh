#!/bin/bash
set -euo pipefail
NS="rev1-q03"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
STATUS=$(helm status web-frontend -n "$NS" -o json 2>/dev/null | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['info']['status'])" 2>/dev/null || echo "")
[ "$STATUS" = "deployed" ] || fail "Helm release status='$STATUS', expected 'deployed'"
pass "Helm release web-frontend is deployed"
