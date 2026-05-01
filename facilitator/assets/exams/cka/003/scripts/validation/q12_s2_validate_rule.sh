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

CR=q12-impersonate-limited-user
VERB=$(kubectl get clusterrole "$CR" -o jsonpath='{.rules[0].verbs[*]}' 2>/dev/null)
RES=$(kubectl get clusterrole "$CR" -o jsonpath='{.rules[0].resources[*]}' 2>/dev/null)
RN=$(kubectl get clusterrole "$CR" -o jsonpath='{.rules[0].resourceNames[*]}' 2>/dev/null)
echo "$VERB" | grep -qw impersonate || fail "ClusterRole must grant impersonate"
echo "$RES" | grep -qw users || fail "ClusterRole must target users"
echo "$RN" | grep -qw limited-user || fail "ClusterRole must restrict resourceNames to limited-user"
pass "Impersonation rule is least privilege"
