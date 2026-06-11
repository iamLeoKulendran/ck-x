#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="credential-hygiene"

JSON=$(kubectl -n "$NS" get deployment billing -o json)

SECRET_NAME=$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].env[] | select(.name=="DB_PASSWORD") | .valueFrom.secretKeyRef.name // empty')
SECRET_KEY=$(echo "$JSON" | jq -r '.spec.template.spec.containers[0].env[] | select(.name=="DB_PASSWORD") | .valueFrom.secretKeyRef.key // empty')

[ "$SECRET_NAME" = "db-creds" ] || fail "DB_PASSWORD must come from secret db-creds, got: ${SECRET_NAME:-configmap/none}"
[ "$SECRET_KEY" = "password" ] || fail "DB_PASSWORD must use secret key 'password', got: ${SECRET_KEY:-none}"

READY=$(echo "$JSON" | jq -r '.status.readyReplicas // 0')
[ "$READY" = "1" ] || fail "billing must be Ready after the change, got readyReplicas=$READY"

echo "PASS: billing consumes the credential from the Secret and is Ready"
exit 0
