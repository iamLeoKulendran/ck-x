#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="ci-pipeline"

kubectl -n "$NS" get role build-bot-role >/dev/null 2>&1 || fail "Role 'build-bot-role' not found in $NS"
kubectl -n "$NS" get rolebinding build-bot-binding >/dev/null 2>&1 || fail "RoleBinding 'build-bot-binding' not found in $NS"

RULES=$(kubectl -n "$NS" get role build-bot-role -o json)

echo "$RULES" | jq -e '.rules[] | select(.resources | index("pods"))' >/dev/null \
  || fail "Role must grant access to pods"
echo "$RULES" | jq -e '.rules[] | select(.resources | index("pods/log"))' >/dev/null \
  || fail "Role must grant access to pods/log"

BAD_VERBS=$(echo "$RULES" | jq -r '[.rules[].verbs[]] | map(select(. == "create" or . == "delete" or . == "update" or . == "patch" or . == "*" or . == "deletecollection")) | length')
[ "$BAD_VERBS" = "0" ] || fail "Role must be read-only (get/list/watch); found write or wildcard verbs"

BAD_RES=$(echo "$RULES" | jq -r '[.rules[].resources[]] | map(select(. == "secrets" or . == "*")) | length')
[ "$BAD_RES" = "0" ] || fail "Role must not grant access to secrets or wildcard resources"

SUBJ=$(kubectl -n "$NS" get rolebinding build-bot-binding -o jsonpath='{.subjects[0].kind}/{.subjects[0].name}')
[ "$SUBJ" = "ServiceAccount/build-bot" ] || fail "RoleBinding must bind ServiceAccount build-bot, got: $SUBJ"

REF=$(kubectl -n "$NS" get rolebinding build-bot-binding -o jsonpath='{.roleRef.kind}/{.roleRef.name}')
[ "$REF" = "Role/build-bot-role" ] || fail "RoleBinding must reference Role build-bot-role, got: $REF"

echo "PASS: least-privilege Role and RoleBinding are correctly structured"
exit 0
