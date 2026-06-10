#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q07
DEP=q7-broken-web
kubectl get deploy "$DEP" -n "$NS" >/dev/null 2>&1 || fail "Deployment $DEP not found"
REV=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null || echo "0")
[ "${REV:-0}" -ge 2 ] 2>/dev/null || fail "Rollout revision is ${REV:-0}, expected >= 2 (rollback or re-set must have occurred)"
GEN=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.metadata.generation}' 2>/dev/null || echo "0")
OBS=$(kubectl get deploy "$DEP" -n "$NS" -o jsonpath='{.status.observedGeneration}' 2>/dev/null || echo "0")
[ "${GEN:-0}" = "${OBS:-0}" ] || fail "Rollout not settled: spec generation $GEN != observed $OBS"
pass "Rollout settled at revision $REV (generation $GEN observed)"
