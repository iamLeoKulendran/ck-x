#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="registry-guard"

# Guard: enforcement must be active, otherwise admitting a pod proves nothing
kubectl get validatingadmissionpolicy trusted-registry-only >/dev/null 2>&1 \
  || fail "trusted-registry-only policy missing; enforcement not in place"
kubectl get validatingadmissionpolicybinding trusted-registry-only-binding >/dev/null 2>&1 \
  || fail "trusted-registry-only-binding missing; enforcement not in place"

kubectl -n "$NS" delete pod vap-compliant --ignore-not-found=true --grace-period=0 >/dev/null 2>&1 || true

OUT=$(kubectl -n "$NS" run vap-compliant --image=registry.localhost:5000/ckx/nginx:v1.25 \
        --restart=Never 2>&1 || true)

if echo "$OUT" | grep -qiE "denied|forbidden"; then
  kubectl -n "$NS" delete pod vap-compliant --ignore-not-found=true --grace-period=0 >/dev/null 2>&1 || true
  fail "a compliant registry.localhost image pod was wrongly rejected (output: $OUT)"
fi

kubectl -n "$NS" get pod vap-compliant >/dev/null 2>&1 \
  || { kubectl -n "$NS" delete pod vap-compliant --ignore-not-found=true --grace-period=0 >/dev/null 2>&1 || true; fail "compliant pod was not admitted"; }

kubectl -n "$NS" delete pod vap-compliant --ignore-not-found=true --grace-period=0 >/dev/null 2>&1 || true
echo "PASS: compliant registry.localhost image pod is admitted in registry-guard"
exit 0
