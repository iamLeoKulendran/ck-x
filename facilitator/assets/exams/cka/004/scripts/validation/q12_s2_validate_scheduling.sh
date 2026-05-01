#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q12
POD=q12-tolerant
OS=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.nodeSelector.kubernetes\.io/os}')
[ "$OS" = "linux" ] || fail "Missing nodeSelector kubernetes.io/os=linux"
YAML=$(kubectl get pod "$POD" -n "$NS" -o yaml)
echo "$YAML" | grep -q 'key: workload' || fail "Missing toleration key workload"
echo "$YAML" | grep -q 'operator: Equal' || fail "Missing toleration operator Equal"
echo "$YAML" | grep -q 'value: reserved' || fail "Missing toleration value reserved"
echo "$YAML" | grep -q 'effect: NoSchedule' || fail "Missing toleration effect NoSchedule"
pass "Scheduling configuration is correct"
