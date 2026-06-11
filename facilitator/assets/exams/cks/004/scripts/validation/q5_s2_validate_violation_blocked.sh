#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="registry-guard"

# Guard: the policy + binding must exist, otherwise the cluster would admit anything
kubectl get validatingadmissionpolicy trusted-registry-only >/dev/null 2>&1 \
  || fail "trusted-registry-only policy missing; enforcement not in place"
kubectl get validatingadmissionpolicybinding trusted-registry-only-binding >/dev/null 2>&1 \
  || fail "trusted-registry-only-binding missing; enforcement not in place"

OUT=$(kubectl -n "$NS" run vap-violation --image=nginx:1.25 --restart=Never \
        --command -- sleep 3600 2>&1 || true)
kubectl -n "$NS" delete pod vap-violation --ignore-not-found=true --grace-period=0 >/dev/null 2>&1 || true

echo "$OUT" | grep -qiE "denied|trusted-registry-only|registry.localhost" \
  || fail "a pod using nginx:1.25 was not rejected by the policy (output: $OUT)"

echo "PASS: non-registry image pod is rejected in registry-guard"
exit 0
