#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q5/kube-apiserver.yaml"

[ -f "$FILE" ] || fail "Manifest $FILE not found (rerun setup)"

AUTHZ=$(yq eval '.spec.containers[0].command[]' "$FILE" | grep -- '--authorization-mode=' || true)
[ -n "$AUTHZ" ] || fail "--authorization-mode flag is missing"

if echo "$AUTHZ" | grep -q "AlwaysAllow"; then
  fail "--authorization-mode must not contain AlwaysAllow"
fi
echo "$AUTHZ" | grep -q "Node" || fail "--authorization-mode must include Node"
echo "$AUTHZ" | grep -q "RBAC" || fail "--authorization-mode must include RBAC"

echo "PASS: authorization mode hardened to Node,RBAC"
exit 0
