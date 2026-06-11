#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="dev-portal"

# Guard: RBAC objects must exist before effective access means anything
kubectl -n "$NS" get role portal-pod-reader >/dev/null 2>&1 || fail "Role portal-pod-reader not found"

can() { kubectl auth can-i "$@" 2>/dev/null || true; }

[ "$(can get pods -n "$NS" --as=dev-lena)" = "yes" ] || fail "dev-lena must be able to get pods in $NS"
[ "$(can watch pods -n "$NS" --as=dev-lena)" = "yes" ] || fail "dev-lena must be able to watch pods in $NS"
[ "$(can get pods/log -n "$NS" --as=dev-lena)" = "yes" ] || fail "dev-lena must be able to read pod logs in $NS"
[ "$(can delete pods -n "$NS" --as=dev-lena)" = "no" ] || fail "dev-lena must NOT be able to delete pods"
[ "$(can get secrets -n "$NS" --as=dev-lena)" = "no" ] || fail "dev-lena must NOT be able to read secrets"
[ "$(can list pods --all-namespaces --as=dev-lena)" = "no" ] || fail "dev-lena must NOT see pods cluster-wide"

echo "PASS: dev-lena has read-only pod access and denied actions are refused"
exit 0
