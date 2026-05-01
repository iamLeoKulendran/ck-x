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

NS=rbac-sec-q1
kubectl -n "$NS" get role q1-pod-reader >/dev/null 2>&1 || fail "Role q1-pod-reader is missing"
kubectl -n "$NS" get rolebinding q1-read-pods >/dev/null 2>&1 || fail "RoleBinding q1-read-pods is missing"
SUBJ=$(kubectl -n "$NS" get rolebinding q1-read-pods -o jsonpath='{.subjects[0].kind}:{.subjects[0].namespace}:{.subjects[0].name}' 2>/dev/null)
REF=$(kubectl -n "$NS" get rolebinding q1-read-pods -o jsonpath='{.roleRef.kind}:{.roleRef.name}' 2>/dev/null)
[ "$SUBJ" = "ServiceAccount:$NS:report-reader" ] || fail "RoleBinding subject must be ServiceAccount ${NS}/report-reader"
[ "$REF" = "Role:q1-pod-reader" ] || fail "RoleBinding must reference Role q1-pod-reader"
pass "RoleBinding references the expected ServiceAccount and Role"
