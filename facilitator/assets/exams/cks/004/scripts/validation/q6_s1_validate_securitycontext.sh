#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="system-lockdown"

kubectl -n "$NS" get deployment edge-cache >/dev/null 2>&1 || fail "edge-cache deployment missing"
SC=$(kubectl -n "$NS" get deployment edge-cache -o json | jq '.spec.template.spec.containers[0].securityContext')

echo "$SC" | jq -e '.capabilities.drop | index("ALL")' >/dev/null \
  || fail "container must drop ALL capabilities"
echo "$SC" | jq -e '(.capabilities.add // []) | length == 0' >/dev/null \
  || fail "container must not add any capabilities back"
echo "$SC" | jq -e '.runAsNonRoot == true' >/dev/null \
  || fail "container must set runAsNonRoot: true"
echo "$SC" | jq -e '.runAsUser == 10001' >/dev/null \
  || fail "container must set runAsUser: 10001"
echo "$SC" | jq -e '.allowPrivilegeEscalation == false' >/dev/null \
  || fail "container must set allowPrivilegeEscalation: false"
echo "$SC" | jq -e '.readOnlyRootFilesystem == true' >/dev/null \
  || fail "container must set readOnlyRootFilesystem: true"

echo "PASS: edge-cache securityContext is hardened"
exit 0
