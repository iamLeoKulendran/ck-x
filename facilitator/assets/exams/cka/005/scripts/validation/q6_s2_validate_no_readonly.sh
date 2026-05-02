#!/bin/bash
set -euo pipefail
NS="rev1-q06"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get pod data-processor >/dev/null 2>&1 || fail "Pod data-processor not found"
READONLY=$(kubectl -n "$NS" get pod data-processor \
  -o jsonpath='{.spec.containers[0].volumeMounts[0].readOnly}' 2>/dev/null || echo "false")
[ "$READONLY" = "true" ] && fail "volumeMount readOnly is still 'true'"
pass "volumeMount readOnly flag is not true"
