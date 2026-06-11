#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="stock-system"

kubectl -n "$NS" rollout status deployment/inventory-api --timeout=60s >/dev/null 2>&1 || fail "inventory-api rollout is not complete"

TOKEN=$(timeout 20 kubectl -n "$NS" exec deploy/inventory-api -- cat /var/run/vault/token 2>/dev/null || true)
[ -n "$TOKEN" ] || fail "projected token not readable at /var/run/vault/token"

timeout 20 kubectl -n "$NS" exec deploy/inventory-api -- sh -c '[ ! -e /var/run/secrets/kubernetes.io/serviceaccount/token ]' \
  || fail "default ServiceAccount token is still mounted"

echo "PASS: workload Ready with the vault token mounted and the default token absent"
exit 0
