#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="stock-system"

JSON=$(kubectl -n "$NS" get deployment inventory-api -o json)

SAT=$(echo "$JSON" | jq '[.spec.template.spec.volumes[]? | select(.name=="vault-token") | .projected.sources[]? | .serviceAccountToken // empty] | first // empty')
[ -n "$SAT" ] && [ "$SAT" != "null" ] || fail "volume vault-token with a projected serviceAccountToken source not found"
[ "$(echo "$SAT" | jq -r '.audience')" = "internal-vault" ] || fail "projected token audience must be internal-vault"
[ "$(echo "$SAT" | jq -r '.expirationSeconds')" = "600" ] || fail "projected token expirationSeconds must be 600"
[ "$(echo "$SAT" | jq -r '.path')" = "token" ] || fail "projected token path must be token"

MOUNT=$(echo "$JSON" | jq '[.spec.template.spec.containers[].volumeMounts[]? | select(.name=="vault-token")] | first // empty')
[ -n "$MOUNT" ] && [ "$MOUNT" != "null" ] || fail "vault-token volume is not mounted"
[ "$(echo "$MOUNT" | jq -r '.mountPath')" = "/var/run/vault" ] || fail "vault-token must be mounted at /var/run/vault"
[ "$(echo "$MOUNT" | jq -r '.readOnly')" = "true" ] || fail "vault-token mount must be readOnly"

echo "PASS: projected vault token volume configured correctly"
exit 0
