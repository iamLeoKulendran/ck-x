#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/etc/kubernetes/manifests/q22-static-web.yaml
grep -q 'image: nginx:1.25' "$FILE" || fail "Image must be nginx:1.25"
grep -q 'containerPort: 80' "$FILE" || fail "containerPort must be 80"
pass "Static Pod manifest spec is correct"
