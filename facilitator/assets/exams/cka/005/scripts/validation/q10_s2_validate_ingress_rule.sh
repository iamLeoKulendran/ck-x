#!/bin/bash
set -euo pipefail
NS="rev1-q10"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get networkpolicy api-policy >/dev/null 2>&1 || fail "NetworkPolicy api-policy not found"
FROM_SELECTOR=$(kubectl -n "$NS" get networkpolicy api-policy \
  -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.app}' 2>/dev/null || echo "")
[ "$FROM_SELECTOR" = "frontend" ] || fail "Ingress from selector app='$FROM_SELECTOR', expected 'frontend'"
PORT=$(kubectl -n "$NS" get networkpolicy api-policy \
  -o jsonpath='{.spec.ingress[0].ports[0].port}' 2>/dev/null || echo "")
[ "$PORT" = "8080" ] || fail "Ingress port='$PORT', expected '8080'"
pass "Ingress rule allows app=frontend on port 8080"
