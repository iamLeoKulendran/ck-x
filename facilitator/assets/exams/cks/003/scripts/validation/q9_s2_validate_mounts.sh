#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="intra-tls"

JSON=$(kubectl -n "$NS" get deployment orders-app -o json)

echo "$JSON" | jq -e '[.spec.template.spec.volumes[]? | select(.secret.secretName=="orders-tls")] | length > 0' >/dev/null \
  || fail "deployment must mount the orders-tls secret via a volume"
echo "$JSON" | jq -e '[.spec.template.spec.volumes[]? | select(.configMap.name=="orders-tls-conf")] | length > 0' >/dev/null \
  || fail "deployment must mount the orders-tls-conf ConfigMap via a volume"
echo "$JSON" | jq -e '[.spec.template.spec.containers[].volumeMounts[]? | select(.mountPath=="/etc/nginx/tls")] | length > 0' >/dev/null \
  || fail "certificate volume must be mounted at /etc/nginx/tls"
echo "$JSON" | jq -e '[.spec.template.spec.containers[].volumeMounts[]? | select(.mountPath=="/etc/nginx/conf.d")] | length > 0' >/dev/null \
  || fail "TLS server config must be mounted at /etc/nginx/conf.d"

kubectl -n "$NS" rollout status deployment/orders-app --timeout=60s >/dev/null 2>&1 || fail "orders-app rollout is not complete"

echo "PASS: certificate and TLS config mounted; orders-app Ready"
exit 0
