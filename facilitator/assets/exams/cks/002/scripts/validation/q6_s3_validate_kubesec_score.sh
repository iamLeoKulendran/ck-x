#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="container-hardening"

kubectl -n "$NS" get deployment sensor-agent -o yaml > /tmp/q6_live_manifest.yaml 2>/dev/null \
  || fail "Cannot export sensor-agent manifest"

SCORE=$(kubesec scan /tmp/q6_live_manifest.yaml 2>/dev/null | jq -r '.[0].score')
rm -f /tmp/q6_live_manifest.yaml

[ -n "$SCORE" ] && [ "$SCORE" != "null" ] || fail "kubesec did not return a score"

if [ "$SCORE" -lt 7 ]; then
  fail "kubesec score must be at least 7, got $SCORE"
fi

echo "PASS: kubesec score is $SCORE (>= 7)"
exit 0
