#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="admission-control"
PROBE="ckx-vap-probe-ok"

# Guard: the enforcing binding must exist, otherwise this passes on fresh state
kubectl get validatingadmissionpolicybinding deny-latest-tag-binding >/dev/null 2>&1 \
  || fail "Policy binding missing; admission control not in place"

kubectl -n "$NS" delete deployment "$PROBE" --ignore-not-found=true >/dev/null 2>&1 || true

if ! kubectl -n "$NS" create deployment "$PROBE" --image=nginx:1.27-alpine --replicas=0 >/dev/null 2>&1; then
  fail "Deployment with pinned tag nginx:1.27-alpine was rejected; compliant workloads must be accepted"
fi
kubectl -n "$NS" delete deployment "$PROBE" --ignore-not-found=true >/dev/null 2>&1 || true

echo "PASS: pinned-tag deployment is accepted while policy is enforcing"
exit 0
