#!/bin/bash
set -euo pipefail
NS="rev1-q14"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get service api-svc >/dev/null 2>&1 || fail "Service api-svc not found"
TARGET=$(kubectl -n "$NS" get service api-svc \
  -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "")
[ "$TARGET" = "8080" ] || fail "Service api-svc targetPort='$TARGET', expected '8080'"
pass "Service api-svc targetPort is 8080"
