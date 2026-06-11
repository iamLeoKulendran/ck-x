#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
DIR="/tmp/exam/q11"

check_report() {
  local file="$1" image="$2"
  [ -f "$file" ] || fail "Report $file not found"
  jq -e . "$file" >/dev/null 2>&1 || fail "$file is not valid JSON"
  local artifact
  artifact=$(jq -r '.ArtifactName // empty' "$file")
  [ "$artifact" = "$image" ] || fail "$file must be a trivy scan of $image, got artifact: ${artifact:-none}"
  jq -e '.Results' "$file" >/dev/null 2>&1 || fail "$file has no trivy Results section"
}

check_report "$DIR/nginx.json" "nginx:1.14.2"
check_report "$DIR/python.json" "python:3.4-alpine"
check_report "$DIR/alpine.json" "alpine:3.20"

echo "PASS: all three trivy scan reports are present and valid"
exit 0
