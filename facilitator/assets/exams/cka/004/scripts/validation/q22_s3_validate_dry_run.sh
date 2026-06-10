#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q22/q22-static-web.yaml
[ -f "$FILE" ] || fail "Manifest missing: $FILE"
OUT=$(kubectl apply --dry-run=client -f "$FILE" 2>&1) || fail "kubectl dry-run rejected manifest: $OUT"
echo "$OUT" | grep -q 'q22-static-web' || fail "kubectl dry-run output did not mention q22-static-web (unexpected resource name)"
pass "Manifest is valid Kubernetes YAML (kubectl dry-run accepted)"
