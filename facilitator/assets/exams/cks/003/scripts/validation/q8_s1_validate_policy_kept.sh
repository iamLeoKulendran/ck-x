#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="checkout"

JSON=$(kubectl -n "$NS" get deployment checkout-api -o json)

echo "$JSON" | jq -e '(.spec.template.spec.securityContext.runAsNonRoot == true) or (.spec.template.spec.containers[0].securityContext.runAsNonRoot == true)' >/dev/null \
  || fail "runAsNonRoot: true must remain enforced"
[ "$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].image')" = "nginxinc/nginx-unprivileged:1.27-alpine" ] \
  || fail "container must use the approved image nginxinc/nginx-unprivileged:1.27-alpine"

echo "PASS: policy kept and approved non-root image in use"
exit 0
