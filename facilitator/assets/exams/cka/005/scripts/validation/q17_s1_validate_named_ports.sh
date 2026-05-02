#!/bin/bash
set -euo pipefail
NS="rev1-q17"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get deployment dual-svc-app >/dev/null 2>&1 || fail "Deployment dual-svc-app not found"
HTTP_PORT=$(kubectl -n "$NS" get deployment dual-svc-app \
  -o jsonpath='{.spec.template.spec.containers[0].ports[?(@.name=="http")].containerPort}' 2>/dev/null || echo "")
[ "$HTTP_PORT" = "8080" ] || fail "Named port 'http' containerPort='$HTTP_PORT', expected '8080'"
METRICS_PORT=$(kubectl -n "$NS" get deployment dual-svc-app \
  -o jsonpath='{.spec.template.spec.containers[0].ports[?(@.name=="metrics")].containerPort}' 2>/dev/null || echo "")
[ "$METRICS_PORT" = "9090" ] || fail "Named port 'metrics' containerPort='$METRICS_PORT', expected '9090'"
pass "Deployment has named ports: http->8080 and metrics->9090"
