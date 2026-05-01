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

NS=rbac-sec-q22
DEP=q22-restricted-nginx
YAML=$(kubectl -n "$NS" get deploy "$DEP" -o yaml 2>/dev/null) || fail "Deployment missing"
echo "$YAML" | grep -q 'runAsNonRoot: true' || fail "runAsNonRoot must be true"
echo "$YAML" | grep -q 'runAsUser: 101' || fail "runAsUser must be 101"
echo "$YAML" | grep -q 'type: RuntimeDefault' || fail "seccompProfile.type must be RuntimeDefault"
echo "$YAML" | grep -q 'allowPrivilegeEscalation: false' || fail "allowPrivilegeEscalation must be false"
echo "$YAML" | grep -q -- '- ALL' || fail "capabilities must drop ALL"
pass "Restricted securityContext is configured"
