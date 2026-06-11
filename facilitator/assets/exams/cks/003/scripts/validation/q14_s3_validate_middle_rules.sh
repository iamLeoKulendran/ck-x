#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q14/audit-policy.yaml"

[ -f "$FILE" ] || fail "audit policy $FILE not found"
JSON=$(yq -o=json e '.' "$FILE") || fail "audit-policy.yaml is not valid YAML"

echo "$JSON" | jq -e '.rules[1] | (.level == "None")
  and ((.users // []) | index("system:kube-proxy"))
  and ((.verbs // []) | index("watch"))
  and ([.resources[]?.resources[]?] | (index("endpoints") and index("services")))' >/dev/null \
  || fail "rule 2 must drop (None) watch requests by system:kube-proxy on endpoints and services"

echo "$JSON" | jq -e '.rules[2] | (.level == "RequestResponse")
  and ((.verbs // []) | index("create"))
  and ([.resources[]?.resources[]?] | index("pods/exec"))' >/dev/null \
  || fail "rule 3 must log create requests on pods/exec at RequestResponse"

echo "PASS: kube-proxy exclusion and pods/exec auditing rules are in order"
exit 0
