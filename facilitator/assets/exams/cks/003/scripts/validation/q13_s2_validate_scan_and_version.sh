#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
DIR="/tmp/exam/q13"

[ -s "$DIR/sbom-vulns.json" ] || fail "vulnerability scan $DIR/sbom-vulns.json missing or empty"
jq -e . "$DIR/sbom-vulns.json" >/dev/null 2>&1 || fail "sbom-vulns.json is not valid JSON"
jq -e '.Results' "$DIR/sbom-vulns.json" >/dev/null 2>&1 || fail "sbom-vulns.json has no trivy Results section"
grep -q 'CVE-' "$DIR/sbom-vulns.json" || fail "scan of the old image should report at least one CVE"

[ -f "$DIR/nginx-version.txt" ] || fail "nginx-version.txt not found"
VERSION=$(tr -d '[:space:]' < "$DIR/nginx-version.txt")
echo "$VERSION" | grep -qE '^1\.25\.[0-9]+(-r[0-9]+)?$' || fail "nginx-version.txt must contain the 1.25.x version from the SBOM, got '$VERSION'"

echo "PASS: SBOM scanned and nginx version extracted"
exit 0
