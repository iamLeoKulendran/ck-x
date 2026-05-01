#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q16
POD=q16-db-client
kubectl get pod "$POD" -n "$NS" >/dev/null 2>&1 || fail "Pod $POD not found"
YAML=$(kubectl get pod "$POD" -n "$NS" -o yaml)
echo "$YAML" | grep -q 'secretKeyRef:' || fail "DB_USER must use secretKeyRef"
echo "$YAML" | grep -q 'key: username' || fail "Missing username key reference"
echo "$YAML" | grep -q 'secretName: q16-db-secret' || fail "Missing Secret volume reference"
echo "$YAML" | grep -q 'mountPath: /etc/db-secret' || fail "Missing mountPath /etc/db-secret"
echo "$YAML" | grep -q 'readOnly: true' || fail "Secret mount must be readOnly"
pass "Pod Secret usage is correct"
