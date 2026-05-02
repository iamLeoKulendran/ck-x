#!/bin/bash
set -euo pipefail
NS="rev1-q17"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get service dual-svc >/dev/null 2>&1 || fail "Service dual-svc not found"
HTTP_TARGET=$(kubectl -n "$NS" get service dual-svc \
  -o jsonpath='{.spec.ports[?(@.port==80)].targetPort}' 2>/dev/null || echo "")
[ "$HTTP_TARGET" = "http" ] || fail "Port 80 targetPort='$HTTP_TARGET', expected string 'http' (not numeric)"
METRICS_TARGET=$(kubectl -n "$NS" get service dual-svc \
  -o jsonpath='{.spec.ports[?(@.port==9090)].targetPort}' 2>/dev/null || echo "")
[ "$METRICS_TARGET" = "metrics" ] || fail "Port 9090 targetPort='$METRICS_TARGET', expected string 'metrics' (not numeric)"
pass "Service dual-svc uses named targetPorts: http and metrics"
