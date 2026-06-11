#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="node-ops"

# Guard: hardening must be in the spec before runtime state counts
[ "$(kubectl -n "$NS" get deployment host-inspector -o jsonpath='{.spec.template.spec.hostNetwork}')" != "true" ] || fail "hostNetwork still enabled"

kubectl -n "$NS" rollout status deployment/host-inspector --timeout=60s >/dev/null 2>&1 || fail "host-inspector rollout is not complete"

POD=$(kubectl -n "$NS" get pod -l app=host-inspector --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[ -n "$POD" ] || fail "no Running host-inspector pod found"

POD_IP=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.podIP}')
HOST_IP=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.hostIP}')
[ -n "$POD_IP" ] && [ "$POD_IP" != "$HOST_IP" ] || fail "pod still runs on the host network (pod IP equals node IP)"

echo "PASS: deployment Ready and running off the host network"
exit 0
