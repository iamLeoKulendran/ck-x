#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
DIR="/tmp/exam/q11"

[ -s "$DIR/trivy-report.txt" ] || fail "trivy report $DIR/trivy-report.txt missing or empty"
grep -qiE 'KSV|AVD-|misconfig|privileged|HIGH|CRITICAL' "$DIR/trivy-report.txt" \
  || fail "trivy report does not contain misconfiguration findings"

[ -s "$DIR/kubesec-report.json" ] || fail "kubesec report $DIR/kubesec-report.json missing or empty"
jq -e . "$DIR/kubesec-report.json" >/dev/null 2>&1 || fail "kubesec-report.json is not valid JSON"

echo "PASS: scan reports produced for the manifest"
exit 0
