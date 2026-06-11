#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="node-ops"

JSON=$(kubectl -n "$NS" get deployment host-inspector -o json)

echo "$JSON" | jq -e '(.spec.template.spec.securityContext.runAsNonRoot == true) or (.spec.template.spec.containers[0].securityContext.runAsNonRoot == true)' >/dev/null \
  || fail "runAsNonRoot: true must be set"
echo "$JSON" | jq -e '(.spec.template.spec.securityContext.runAsUser == 10001) or (.spec.template.spec.containers[0].securityContext.runAsUser == 10001)' >/dev/null \
  || fail "runAsUser: 10001 must be set"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation == false' >/dev/null \
  || fail "allowPrivilegeEscalation: false must be set on the container"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].securityContext.capabilities.drop | index("ALL")' >/dev/null \
  || fail "the container must drop ALL capabilities"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem == true' >/dev/null \
  || fail "readOnlyRootFilesystem: true must be set on the container"

echo "PASS: hardened securityContext enforced"
exit 0
