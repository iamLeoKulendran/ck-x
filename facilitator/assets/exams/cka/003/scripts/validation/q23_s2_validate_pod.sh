#!/bin/bash
set +e
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NS=rbac-sec-q23
POD=q23-db-client
kubectl -n "$NS" get pod "$POD" >/dev/null 2>&1 || fail "Pod q23-db-client missing"
YAML=$(kubectl -n "$NS" get pod "$POD" -o yaml)
echo "$YAML" | grep -q 'name: DB_USER' || fail "DB_USER env var missing"
echo "$YAML" | grep -q 'secretKeyRef:' || fail "DB_USER must use secretKeyRef"
echo "$YAML" | grep -q 'secretName: q23-db-secret' || fail "Secret volume must reference q23-db-secret"
echo "$YAML" | grep -q 'mountPath: /etc/db-secret' || fail "Secret must be mounted at /etc/db-secret"
echo "$YAML" | grep -q 'readOnly: true' || fail "Secret volumeMount must be readOnly"
pass "Pod secret usage is correct"
