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

NS=rbac-sec-q14
POD=q14-secure-pod
YAML=$(kubectl -n "$NS" get pod "$POD" -o yaml 2>/dev/null) || fail "q14-secure-pod missing"
echo "$YAML" | grep -q 'allowPrivilegeEscalation: false' || fail "allowPrivilegeEscalation must be false"
echo "$YAML" | grep -q 'readOnlyRootFilesystem: true' || fail "readOnlyRootFilesystem must be true"
echo "$YAML" | grep -q 'type: RuntimeDefault' || fail "seccompProfile.type must be RuntimeDefault"
echo "$YAML" | grep -q 'drop:' || fail "capabilities.drop missing"
echo "$YAML" | grep -q -- '- ALL' || fail "capabilities must drop ALL"
pass "Container hardening settings are correct"
