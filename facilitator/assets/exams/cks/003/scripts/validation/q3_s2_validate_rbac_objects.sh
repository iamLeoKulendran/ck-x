#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="dev-portal"

kubectl -n "$NS" get role portal-pod-reader >/dev/null 2>&1 || fail "Role portal-pod-reader not found"
ROLE=$(kubectl -n "$NS" get role portal-pod-reader -o json)

echo "$ROLE" | jq -e '[.rules[].resources[]] | index("pods")' >/dev/null || fail "Role must allow pods"
echo "$ROLE" | jq -e '[.rules[].resources[]] | index("pods/log")' >/dev/null || fail "Role must allow pods/log"
echo "$ROLE" | jq -e '([.rules[].verbs[]] | unique) - ["get","list","watch"] | length == 0' >/dev/null || fail "Role must allow only get, list, watch"
echo "$ROLE" | jq -e '[.rules[].resources[]] | index("secrets") | not' >/dev/null || fail "Role must not grant secrets access"

kubectl -n "$NS" get rolebinding dev-lena-pod-reader >/dev/null 2>&1 || fail "RoleBinding dev-lena-pod-reader not found"
RB=$(kubectl -n "$NS" get rolebinding dev-lena-pod-reader -o json)
[ "$(echo "$RB" | jq -r '.roleRef.kind')" = "Role" ] || fail "RoleBinding must reference a Role"
[ "$(echo "$RB" | jq -r '.roleRef.name')" = "portal-pod-reader" ] || fail "RoleBinding must reference portal-pod-reader"
echo "$RB" | jq -e '.subjects[] | select(.kind=="User" and .name=="dev-lena")' >/dev/null || fail "RoleBinding must bind the user dev-lena"

echo "PASS: least-privilege Role and RoleBinding are correct"
exit 0
