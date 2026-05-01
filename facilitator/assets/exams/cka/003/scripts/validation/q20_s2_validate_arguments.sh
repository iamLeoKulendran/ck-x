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

FILE=/tmp/exam/q20/inspect_rbac.sh
grep -q -- '--as=system:serviceaccount:rbac-sec-q20:troubleshoot-sa\|--as system:serviceaccount:rbac-sec-q20:troubleshoot-sa' "$FILE" || fail "Script must use correct --as ServiceAccount"
grep -Eq -- '(-n|--namespace)(=| )rbac-sec-q20' "$FILE" || fail "Script must target namespace rbac-sec-q20"
bash "$FILE" >/tmp/exam/q20/inspect_rbac.out 2>/tmp/exam/q20/inspect_rbac.err || fail "Script must run successfully"
grep -Eq 'Resources|Non-Resource URLs|Verbs' /tmp/exam/q20/inspect_rbac.out || fail "Script output does not look like can-i --list"
pass "RBAC inspection script uses correct arguments"
