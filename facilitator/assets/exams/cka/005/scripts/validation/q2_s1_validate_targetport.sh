#!/bin/bash
set -euo pipefail
NS="rev1-q02"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get service frontend-svc >/dev/null 2>&1 || fail "Service frontend-svc not found"
TARGET=$(kubectl -n "$NS" get service frontend-svc -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "")
[ "$TARGET" = "8080" ] || fail "Service targetPort='$TARGET', expected '8080'"
pass "Service frontend-svc targetPort is 8080"
