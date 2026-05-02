#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
[ -f /tmp/exam/q7/merged-config.yaml ] || fail "/tmp/exam/q7/merged-config.yaml not found"
grep -q "prod-context" /tmp/exam/q7/merged-config.yaml || fail "'prod-context' not found in merged-config.yaml"
pass "'prod-context' found in merged-config.yaml"
