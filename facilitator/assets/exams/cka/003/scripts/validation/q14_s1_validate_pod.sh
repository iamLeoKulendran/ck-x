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
kubectl -n "$NS" get pod "$POD" >/dev/null 2>&1 || fail "q14-secure-pod missing"
IMG=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.containers[0].image}')
RN=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.securityContext.runAsNonRoot}{.spec.containers[0].securityContext.runAsNonRoot}')
RU=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.securityContext.runAsUser}{.spec.containers[0].securityContext.runAsUser}')
[ "$IMG" = "nginx:1.25" ] || fail "Image must be nginx:1.25"
echo "$RN" | grep -q true || fail "runAsNonRoot must be true"
echo "$RU" | grep -q 101 || fail "runAsUser must be 101"
pass "Pod exists with non-root identity"
