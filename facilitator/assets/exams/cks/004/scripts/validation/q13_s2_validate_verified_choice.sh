#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
F="/tmp/exam/q13/verified.txt"

[ -s "$F" ] || fail "verified.txt missing or empty at $F"

# The authentic manifest is release-good.yaml (release-bad.yaml was tampered post-signing)
grep -q "release-good.yaml" "$F" || fail "verified.txt must name release-good.yaml as the authentic manifest"
if grep -q "release-bad.yaml" "$F"; then
  fail "verified.txt must not name the tampered release-bad.yaml"
fi

# Re-confirm the cryptographic fact: good signature verifies, bad does not
export COSIGN_PASSWORD=""
cosign verify-blob --key /tmp/exam/q13/releaser.pub \
  --signature /tmp/exam/q13/release-good.sig --insecure-ignore-tlog \
  /tmp/exam/q13/release-good.yaml >/dev/null 2>&1 \
  || fail "release-good.yaml signature does not verify (setup integrity issue)"

if cosign verify-blob --key /tmp/exam/q13/releaser.pub \
     --signature /tmp/exam/q13/release-bad.sig --insecure-ignore-tlog \
     /tmp/exam/q13/release-bad.yaml >/dev/null 2>&1; then
  fail "release-bad.yaml unexpectedly verifies; tamper not detected"
fi

echo "PASS: verified.txt correctly identifies release-good.yaml as authentic"
exit 0
