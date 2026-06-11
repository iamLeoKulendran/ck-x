#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="notify"

LOGS=$(timeout 20 kubectl -n "$NS" logs deploy/notify-bot --tail=100 2>/dev/null || true)
[ -n "$LOGS" ] || fail "could not read notify-bot logs"

echo "$LOGS" | grep -q "startup: token loaded" || fail "startup log must read exactly 'startup: token loaded'"
if echo "$LOGS" | grep -q 'ntfy_'; then
  fail "pod logs still expose a token value"
fi

echo "PASS: startup logging no longer exposes the token"
exit 0
