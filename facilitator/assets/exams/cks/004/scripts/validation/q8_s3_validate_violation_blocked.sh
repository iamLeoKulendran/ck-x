#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="microsvc-restricted"

# Guard: the namespace must enforce restricted, otherwise a privileged pod would just run
ENF=$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')
[ "$ENF" = "restricted" ] || fail "namespace does not enforce restricted; cannot block violations"

OUT=$(kubectl -n "$NS" run psa-violation --image=registry.localhost:5000/ckx/nginx:v1.25 \
        --restart=Never --privileged 2>&1 || true)
kubectl -n "$NS" delete pod psa-violation --ignore-not-found=true --grace-period=0 >/dev/null 2>&1 || true

echo "$OUT" | grep -qiE "violat|forbidden|denied|privileged" \
  || fail "a privileged pod was not rejected by the restricted namespace (output: $OUT)"

echo "PASS: privileged pod rejected by restricted namespace"
exit 0
