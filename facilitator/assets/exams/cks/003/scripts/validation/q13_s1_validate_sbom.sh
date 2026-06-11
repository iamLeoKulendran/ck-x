#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q13/sbom.json"

[ -s "$FILE" ] || fail "SBOM $FILE missing or empty"
jq -e . "$FILE" >/dev/null 2>&1 || fail "sbom.json is not valid JSON"
[ "$(jq -r '.bomFormat // empty' "$FILE")" = "CycloneDX" ] || fail "SBOM must be in CycloneDX format"
jq -e '.components | length > 0' "$FILE" >/dev/null || fail "SBOM has no components"
jq -e '[.components[].name] | index("nginx")' "$FILE" >/dev/null || fail "SBOM does not list the nginx component"

echo "PASS: CycloneDX SBOM generated with components"
exit 0
