#!/bin/bash
set -euo pipefail
NS="rev1-q03"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
IMAGE=$(kubectl -n "$NS" get deployment web-frontend \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
[[ "$IMAGE" == *":1.27"* ]] || fail "Deployment image='$IMAGE', expected tag 1.27"
pass "Deployment image tag is 1.27"
