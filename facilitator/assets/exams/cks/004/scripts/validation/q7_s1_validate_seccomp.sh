#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="syscall-lockdown"

kubectl -n "$NS" get deployment metrics-shipper >/dev/null 2>&1 || fail "metrics-shipper deployment missing"
JSON=$(kubectl -n "$NS" get deployment metrics-shipper -o json)

# Pod-level OR container-level seccomp must be RuntimeDefault, and nothing Unconfined
POD_T=$(echo "$JSON" | jq -r '.spec.template.spec.securityContext.seccompProfile.type // empty')
CON_T=$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].securityContext.seccompProfile.type // empty')

if [ "$POD_T" = "Unconfined" ] || [ "$CON_T" = "Unconfined" ]; then
  fail "seccompProfile is still Unconfined"
fi

[ "$POD_T" = "RuntimeDefault" ] || [ "$CON_T" = "RuntimeDefault" ] \
  || fail "seccompProfile.type must be RuntimeDefault (pod or container level)"

echo "PASS: metrics-shipper uses RuntimeDefault seccomp profile"
exit 0
