#!/bin/bash
set -euo pipefail
NS="rev1-q04"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get deployment config-loader >/dev/null 2>&1 || fail "Deployment config-loader not found"
INIT_NAME=$(kubectl -n "$NS" get deployment config-loader \
  -o jsonpath='{.spec.template.spec.initContainers[0].name}' 2>/dev/null || echo "")
[ "$INIT_NAME" = "init-copy" ] || fail "Init container name='$INIT_NAME', expected 'init-copy'"
INIT_IMAGE=$(kubectl -n "$NS" get deployment config-loader \
  -o jsonpath='{.spec.template.spec.initContainers[0].image}' 2>/dev/null || echo "")
[[ "$INIT_IMAGE" == *"busybox"* ]] || fail "Init container image='$INIT_IMAGE', expected busybox"
pass "Deployment config-loader has init container 'init-copy' with busybox"
