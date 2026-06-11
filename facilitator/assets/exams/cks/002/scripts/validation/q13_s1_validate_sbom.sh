#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q13/sbom.json"

[ -f "$FILE" ] || fail "SBOM file $FILE not found"

jq -e . "$FILE" >/dev/null 2>&1 || fail "sbom.json is not valid JSON"

jq -e '.spdxVersion' "$FILE" >/dev/null 2>&1 || fail "sbom.json must be in SPDX JSON format (spdxVersion missing)"

NAME=$(jq -r '.name // empty' "$FILE")
echo "$NAME" | grep -q "alpine" || fail "SBOM must describe the alpine:3.20 image, got name: ${NAME:-none}"

PKG_COUNT=$(jq '.packages | length' "$FILE")
[ "$PKG_COUNT" -gt 1 ] || fail "SBOM contains no packages"

echo "PASS: SPDX SBOM generated for alpine:3.20 with $PKG_COUNT packages"
exit 0
