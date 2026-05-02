#!/bin/bash
set -euo pipefail
NS="rev1-q12"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
CM_NAME=$(kubectl -n "$NS" get configmap -o name 2>/dev/null | grep "configmap/prod-" | head -1 | sed 's|configmap/||' || echo "")
[ -n "$CM_NAME" ] || fail "No ConfigMap with prefix 'prod-' found in $NS"
DATA=$(kubectl -n "$NS" get configmap "$CM_NAME" -o yaml 2>/dev/null || echo "")
echo "$DATA" | grep -q "myapp" || fail "ConfigMap '$CM_NAME' does not contain 'myapp'"
pass "ConfigMap '$CM_NAME' contains app.name=myapp"
