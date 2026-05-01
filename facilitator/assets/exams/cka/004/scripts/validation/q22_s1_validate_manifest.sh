#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/etc/kubernetes/manifests/q22-static-web.yaml
[ -s "$FILE" ] || fail "$FILE not found"
grep -q '^kind: Pod' "$FILE" || fail "Manifest must be kind Pod"
grep -q 'name: q22-static-web' "$FILE" || fail "Pod name must be q22-static-web"
pass "Static Pod manifest exists"
