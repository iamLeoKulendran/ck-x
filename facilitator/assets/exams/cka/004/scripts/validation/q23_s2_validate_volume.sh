#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q23
POD=q23-logger
YAML=$(kubectl get pod "$POD" -n "$NS" -o yaml)
echo "$YAML" | grep -q 'name: log-volume' || fail "Missing log-volume"
echo "$YAML" | grep -q 'emptyDir:' || fail "log-volume must be emptyDir"
[ "$(echo "$YAML" | grep -c 'mountPath: /var/log')" -ge 2 ] || fail "Both containers must mount /var/log"
echo "$YAML" | grep -q '/var/log/app.log' || fail "Commands must reference /var/log/app.log"
pass "Shared logging volume is correct"
