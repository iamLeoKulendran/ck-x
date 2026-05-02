#!/bin/bash
set -euo pipefail
NS="rev1-q14"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get deployment api-server >/dev/null 2>&1 || fail "Deployment api-server not found"
PORT=$(kubectl -n "$NS" get deployment api-server \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null || echo "")
[ "$PORT" = "8080" ] || fail "Readiness probe port='$PORT', expected '8080'"
pass "Deployment api-server readiness probe port is 8080"
