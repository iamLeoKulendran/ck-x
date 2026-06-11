#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="notify"
NEW="ntfy_c4f1e8b2d7a0"

VALUE=$(kubectl -n "$NS" get secret notify-token -o jsonpath='{.data.token}' | base64 -d)
[ "$VALUE" = "$NEW" ] || fail "secret notify-token must hold the replacement value"

kubectl -n "$NS" rollout status deployment/notify-bot --timeout=60s >/dev/null 2>&1 || fail "notify-bot rollout is not complete"

RUNTIME=$(timeout 20 kubectl -n "$NS" exec deploy/notify-bot -- sh -c 'echo -n "$NOTIFY_TOKEN"' 2>/dev/null || true)
[ "$RUNTIME" = "$NEW" ] || fail "running pod still uses the old token; restart the workload after rotating"

echo "PASS: secret rotated and the running pod uses the new token"
exit 0
