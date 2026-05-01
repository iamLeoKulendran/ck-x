#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q18
DEP=q18-web
YAML=$(kubectl get deploy "$DEP" -n "$NS" -o yaml)
echo "$YAML" | grep -q 'podAntiAffinity:' || fail "Missing podAntiAffinity"
echo "$YAML" | grep -q 'preferredDuringSchedulingIgnoredDuringExecution:' || fail "Missing preferred anti-affinity"
echo "$YAML" | grep -q 'topologyKey: kubernetes.io/hostname' || fail "Missing topologyKey kubernetes.io/hostname"
echo "$YAML" | grep -q 'app: q18-web' || fail "Anti-affinity must match app=q18-web"
pass "Anti-affinity is configured"
