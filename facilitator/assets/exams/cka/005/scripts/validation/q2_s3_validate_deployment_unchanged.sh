#!/bin/bash
set -euo pipefail
NS="rev1-q02"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get deployment frontend >/dev/null 2>&1 || fail "Deployment frontend not found"
IMAGE=$(kubectl -n "$NS" get deployment frontend \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
[[ "$IMAGE" == *"hello-app:1.0"* ]] || fail "Deployment image='$IMAGE', expected hello-app:1.0"
pass "Deployment frontend is unchanged with image hello-app:1.0"
