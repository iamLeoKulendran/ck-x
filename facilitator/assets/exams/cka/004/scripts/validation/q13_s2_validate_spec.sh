#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q13
JOB=q13-pi
IMG=$(kubectl get job "$JOB" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMG" = "busybox:1.36" ] || fail "Expected image busybox:1.36, got $IMG"
YAML=$(kubectl get job "$JOB" -n "$NS" -o yaml)
echo "$YAML" | grep -q 'cka-q13-complete' || fail "Fixed command must echo cka-q13-complete"
! echo "$YAML" | grep -q 'exit 1' || fail "Job still contains failing command"
pass "Job spec is fixed"
