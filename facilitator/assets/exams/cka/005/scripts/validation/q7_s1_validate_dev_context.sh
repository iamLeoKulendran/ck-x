#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
[ -f /tmp/exam/q7/merged-config.yaml ] || fail "/tmp/exam/q7/merged-config.yaml not found"
grep -q "dev-context" /tmp/exam/q7/merged-config.yaml || fail "'dev-context' not found in merged-config.yaml"
pass "'dev-context' found in merged-config.yaml"
