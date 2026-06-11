#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="runtime-soc"

SC=$(kubectl -n "$NS" get deployment ingest-api -o json 2>/dev/null \
      | jq '.spec.template.spec.containers[] | select(.name=="api") | .securityContext') \
  || fail "ingest-api deployment missing"

[ -n "$SC" ] && [ "$SC" != "null" ] || fail "api container has no securityContext"

echo "$SC" | jq -e '.allowPrivilegeEscalation == false' >/dev/null \
  || fail "api must set allowPrivilegeEscalation: false"
echo "$SC" | jq -e '.readOnlyRootFilesystem == true' >/dev/null \
  || fail "api must set readOnlyRootFilesystem: true"
echo "$SC" | jq -e '.capabilities.drop | index("ALL")' >/dev/null \
  || fail "api must drop ALL capabilities"

echo "PASS: api container is hardened"
exit 0
