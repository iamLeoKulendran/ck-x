#!/bin/bash
set -euo pipefail
NS="rev1-q04"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get deployment config-loader >/dev/null 2>&1 || fail "Deployment config-loader not found"
INIT_MOUNTS=$(kubectl -n "$NS" get deployment config-loader \
  -o jsonpath='{.spec.template.spec.initContainers[0].volumeMounts[*].name}' 2>/dev/null || echo "")
MAIN_MOUNTS=$(kubectl -n "$NS" get deployment config-loader \
  -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].name}' 2>/dev/null || echo "")
[[ "$INIT_MOUNTS" == *"shared-data"* ]] || fail "Init container does not mount 'shared-data' volume"
[[ "$MAIN_MOUNTS" == *"shared-data"* ]] || fail "Main container does not mount 'shared-data' volume"
pass "emptyDir 'shared-data' is mounted in both init and main containers"
