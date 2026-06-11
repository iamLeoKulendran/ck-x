#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="audit-team"

kubectl -n "$NS" get role report-role >/dev/null 2>&1 || fail "report-role missing in $NS"
JSON=$(kubectl -n "$NS" get role report-role -o json)

# No wildcard resources or verbs anywhere
if echo "$JSON" | jq -e '[.rules[].resources[], .rules[].verbs[]] | index("*")' >/dev/null 2>&1; then
  fail "report-role still contains a wildcard (*) rule"
fi

# Every rule must target only configmaps
echo "$JSON" | jq -e '[.rules[].resources[]] | unique == ["configmaps"]' >/dev/null \
  || fail "report-role must only grant access to configmaps"

# Verbs must be a subset of get/list/watch and include get+list
echo "$JSON" | jq -e '[.rules[].verbs[]] | unique - ["get","list","watch"] | length == 0' >/dev/null \
  || fail "report-role verbs must be limited to get/list/watch"
echo "$JSON" | jq -e '[.rules[].verbs[]] | (index("get") and index("list"))' >/dev/null \
  || fail "report-role must allow at least get and list on configmaps"

echo "PASS: report-role scoped to configmaps get/list/watch with no wildcards"
exit 0
