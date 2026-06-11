#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
F="/tmp/exam/q13/sbom.json"

[ -s "$F" ] || fail "sbom.json missing or empty at $F"

# Must be valid JSON
jq -e . "$F" >/dev/null 2>&1 || fail "sbom.json is not valid JSON"

# Must be SPDX format
jq -e '.spdxVersion // .SPDXID // empty' "$F" >/dev/null 2>&1 \
  || fail "sbom.json is not SPDX-JSON (missing spdxVersion/SPDXID)"

# Must list packages (alpine base image has multiple)
PKGS=$(jq '(.packages // []) | length' "$F")
[ "$PKGS" -ge 3 ] || fail "sbom.json lists too few packages ($PKGS); expected an alpine package inventory"

# Should reference the alpine image somewhere
grep -qi "alpine" "$F" || fail "sbom.json does not reference the alpine image"

echo "PASS: sbom.json is valid SPDX-JSON with an alpine package inventory"
exit 0
