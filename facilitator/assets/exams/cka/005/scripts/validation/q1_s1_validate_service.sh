#!/bin/bash
set -euo pipefail
NS="rev1-q01"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get service db-service >/dev/null 2>&1 || fail "Service db-service not found in $NS"
SELECTOR=$(kubectl -n "$NS" get service db-service -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")
[ "$SELECTOR" = "db" ] || fail "Service selector app='$SELECTOR', expected 'db'"
TARGET=$(kubectl -n "$NS" get service db-service -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "")
[ "$TARGET" = "80" ] || fail "Service targetPort='$TARGET', expected '80'"
PORT=$(kubectl -n "$NS" get service db-service -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")
[ "$PORT" = "5432" ] || fail "Service port='$PORT', expected '5432'"
pass "Service db-service configured correctly (selector=db, port=5432, targetPort=80)"
