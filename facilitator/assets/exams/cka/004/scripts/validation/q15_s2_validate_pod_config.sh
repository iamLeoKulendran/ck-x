#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q15
POD=q15-configured
IMG=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[0].image}')
[ "$IMG" = "nginx:1.25" ] || fail "Expected image nginx:1.25, got $IMG"
YAML=$(kubectl get pod "$POD" -n "$NS" -o yaml)
echo "$YAML" | grep -q 'configMapKeyRef:' || fail "APP_MODE must come from configMapKeyRef"
echo "$YAML" | grep -q 'key: APP_MODE' || fail "Missing APP_MODE key reference"
echo "$YAML" | grep -q 'name: app-settings' || fail "Missing app-settings reference"
echo "$YAML" | grep -q 'mountPath: /etc/app-settings' || fail "Missing mountPath /etc/app-settings"
pass "Pod ConfigMap usage is correct"
