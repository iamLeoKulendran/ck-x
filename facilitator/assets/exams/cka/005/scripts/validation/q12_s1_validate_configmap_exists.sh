#!/bin/bash
set -euo pipefail
NS="rev1-q12"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
CM=$(kubectl -n "$NS" get configmap -o name 2>/dev/null | grep "configmap/prod-" | head -1 || echo "")
[ -n "$CM" ] || fail "No ConfigMap with prefix 'prod-' found in namespace $NS"
pass "ConfigMap with prefix 'prod-' exists: $CM"
