#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="incident-response"

kubectl -n "$NS" get deployment kernel-helper >/dev/null 2>&1 \
  || fail "Deployment kernel-helper was deleted; evidence must be preserved (scale to 0 instead)"

REPLICAS=$(kubectl -n "$NS" get deployment kernel-helper -o jsonpath='{.spec.replicas}')
[ "$REPLICAS" = "0" ] || fail "kernel-helper must be scaled to 0 replicas, got: $REPLICAS"

for APP in metrics-agent log-shipper; do
  R=$(kubectl -n "$NS" get deployment "$APP" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
  [ "${R:-0}" -ge 1 ] || fail "Benign workload $APP must keep running (replicas >= 1)"
done

echo "PASS: compromised workload contained, evidence preserved, benign workloads untouched"
exit 0
