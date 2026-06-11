#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="support-rbac"

kubectl -n "$NS" get role oncall-role >/dev/null 2>&1 || fail "oncall-role missing in $NS"
JSON=$(kubectl -n "$NS" get role oncall-role -o json)

# No wildcards
if echo "$JSON" | jq -e '[.rules[].resources[], .rules[].verbs[]] | index("*")' >/dev/null 2>&1; then
  fail "oncall-role still contains a wildcard (*) rule"
fi

# pods/exec must not be grantable via any create rule
if echo "$JSON" | jq -e '[.rules[] | select(.verbs | index("create")) | .resources[]] | index("pods/exec")' >/dev/null 2>&1; then
  fail "oncall-role still allows create on pods/exec"
fi

# Must grant pods/log get
echo "$JSON" | jq -e '[.rules[] | select(.verbs | index("get")) | .resources[]] | index("pods/log")' >/dev/null \
  || fail "oncall-role must grant get on pods/log"

# Allowed resources limited to pods and pods/log
echo "$JSON" | jq -e '[.rules[].resources[]] | unique - ["pods","pods/log"] | length == 0' >/dev/null \
  || fail "oncall-role must only reference pods and pods/log"

echo "PASS: oncall-role grants pods read + pods/log, no exec, no wildcards"
exit 0
