#!/bin/bash
set -euo pipefail
NS="rev1-q01"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get pod db-backend >/dev/null 2>&1 || fail "Pod db-backend not found in $NS"
LABEL=$(kubectl -n "$NS" get pod db-backend -o jsonpath='{.metadata.labels.app}' 2>/dev/null || echo "")
[ "$LABEL" = "db" ] || fail "Pod label app='$LABEL', expected 'db'"
STATUS=$(kubectl -n "$NS" get pod db-backend -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[ "$STATUS" = "Running" ] || fail "Pod db-backend phase='$STATUS', expected 'Running'"
pass "Pod db-backend is Running with label app=db"
