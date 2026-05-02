#!/bin/bash
set -euo pipefail
NS="rev1-q10"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get networkpolicy api-policy >/dev/null 2>&1 || fail "NetworkPolicy api-policy not found"
TO_SELECTOR=$(kubectl -n "$NS" get networkpolicy api-policy \
  -o jsonpath='{.spec.egress[0].to[0].podSelector.matchLabels.app}' 2>/dev/null || echo "")
[ "$TO_SELECTOR" = "db" ] || fail "Egress to selector app='$TO_SELECTOR', expected 'db'"
PORT=$(kubectl -n "$NS" get networkpolicy api-policy \
  -o jsonpath='{.spec.egress[0].ports[0].port}' 2>/dev/null || echo "")
[ "$PORT" = "5432" ] || fail "Egress port='$PORT', expected '5432'"
pass "Egress rule allows app=db on port 5432"
