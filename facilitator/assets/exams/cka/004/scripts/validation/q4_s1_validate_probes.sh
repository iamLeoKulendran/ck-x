#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q04
POD=waiting-client
kubectl get pod "$POD" -n "$NS" >/dev/null 2>&1 || fail "Pod $POD not found"
kubectl get pod "$POD" -n "$NS" -o yaml | grep -q 'livenessProbe' || fail "Missing livenessProbe"
kubectl get pod "$POD" -n "$NS" -o yaml | grep -q 'readinessProbe' || fail "Missing readinessProbe"
kubectl get pod "$POD" -n "$NS" -o yaml | grep -q 'wget -T2 -O- http://service-check:80' || fail "Readiness probe command is incorrect"
pass "Probe configuration is correct"
