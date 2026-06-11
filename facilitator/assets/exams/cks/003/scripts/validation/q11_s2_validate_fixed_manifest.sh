#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q11/webhook-deploy-fixed.yaml"

[ -f "$FILE" ] || fail "hardened manifest $FILE not found"

JSON=$(yq -o=json e '.' "$FILE") || fail "hardened manifest is not valid YAML"

[ "$(echo "$JSON" | jq -r '.metadata.name')" = "webhook-gw" ] || fail "Deployment name must stay webhook-gw"
[ "$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].image')" = "busybox:1.36" ] || fail "image must be pinned to busybox:1.36"
[ "$(echo "$JSON" | jq -r '.spec.template.spec.hostPID // false')" = "false" ] || fail "hostPID must be removed"
[ "$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].securityContext.privileged // false')" = "false" ] || fail "privileged must be removed"
echo "$JSON" | jq -e '(.spec.template.spec.securityContext.runAsNonRoot == true) or (.spec.template.spec.containers[0].securityContext.runAsNonRoot == true)' >/dev/null \
  || fail "runAsNonRoot: true must be set"
echo "$JSON" | jq -e '(.spec.template.spec.securityContext.runAsUser == 10001) or (.spec.template.spec.containers[0].securityContext.runAsUser == 10001)' >/dev/null \
  || fail "runAsUser: 10001 must be set"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation == false' >/dev/null \
  || fail "allowPrivilegeEscalation: false must be set"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].securityContext.capabilities.drop | index("ALL")' >/dev/null \
  || fail "capabilities must drop ALL"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem == true' >/dev/null \
  || fail "readOnlyRootFilesystem: true must be set"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].resources.limits | has("cpu") and has("memory")' >/dev/null \
  || fail "cpu and memory limits must be set"
echo "$JSON" | jq -e '.spec.template.spec.containers[0].resources.requests | has("cpu") and has("memory")' >/dev/null \
  || fail "cpu and memory requests must be set"

SCORE=$(kubesec scan "$FILE" 2>/dev/null | jq '.[0].score // -100')
[ "$SCORE" -ge 5 ] || fail "kubesec score of the hardened manifest is $SCORE; must be at least 5"

echo "PASS: hardened manifest meets all checklist items (kubesec score $SCORE)"
exit 0
