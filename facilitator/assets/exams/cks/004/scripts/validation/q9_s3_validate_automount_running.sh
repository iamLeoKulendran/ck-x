#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="payments-svc"

kubectl -n "$NS" get deployment billing >/dev/null 2>&1 || fail "billing deployment missing"

# Use jsonpath (jq's // operator treats boolean false as absent)
AM=$(kubectl -n "$NS" get deployment billing -o jsonpath='{.spec.template.spec.automountServiceAccountToken}')
[ "$AM" = "false" ] || fail "billing must set automountServiceAccountToken: false (got: ${AM:-unset})"

POD=$(kubectl -n "$NS" get pods -l app=billing \
       --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
[ -n "$POD" ] || fail "no Running billing pod found"

# Confirm the running pod actually carries automount=false (new spec rolled out)
PAM=$(kubectl -n "$NS" get "${POD}" -o jsonpath='{.spec.automountServiceAccountToken}')
[ "$PAM" = "false" ] || fail "Running billing pod does not disable automountServiceAccountToken"

IMG=$(kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "$IMG" | grep -q "registry.localhost:5000/ckx/nginx:v1.25" \
  || fail "billing pod not using the internal registry image (got: $IMG)"

echo "PASS: billing disables token automount and Runs from the internal registry image"
exit 0
