#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="stock-system"

kubectl -n "$NS" get serviceaccount inventory-sa >/dev/null 2>&1 || fail "ServiceAccount inventory-sa not found"
[ "$(kubectl -n "$NS" get serviceaccount inventory-sa -o jsonpath='{.automountServiceAccountToken}')" = "false" ] \
  || fail "inventory-sa must set automountServiceAccountToken: false"
[ "$(kubectl -n "$NS" get deployment inventory-api -o jsonpath='{.spec.template.spec.serviceAccountName}')" = "inventory-sa" ] \
  || fail "deployment inventory-api must run as inventory-sa"

echo "PASS: inventory-sa exists with automount disabled and is used by the deployment"
exit 0
