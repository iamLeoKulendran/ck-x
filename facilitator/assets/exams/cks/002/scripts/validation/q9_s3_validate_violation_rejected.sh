#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="admission-control"
PROBE="ckx-vap-probe-bad"

kubectl -n "$NS" delete deployment "$PROBE" --ignore-not-found=true >/dev/null 2>&1 || true

if kubectl -n "$NS" create deployment "$PROBE" --image=nginx:latest --replicas=0 >/dev/null 2>&1; then
  kubectl -n "$NS" delete deployment "$PROBE" --ignore-not-found=true >/dev/null 2>&1 || true
  fail "Deployment with nginx:latest was accepted; the policy must reject latest tags"
fi

echo "PASS: latest-tag deployment is rejected by admission policy"
exit 0
