#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
[ -f /tmp/exam/q7/merged-config.yaml ] || fail "/tmp/exam/q7/merged-config.yaml not found"
CURRENT=$(KUBECONFIG=/tmp/exam/q7/merged-config.yaml kubectl config current-context 2>/dev/null || echo "")
[ "$CURRENT" = "prod-context" ] || fail "current-context='$CURRENT', expected 'prod-context'"
pass "current-context in merged-config.yaml is 'prod-context'"
