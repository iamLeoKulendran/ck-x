#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="tls-gateway"

kubectl -n "$NS" get ingress portal-ingress >/dev/null 2>&1 || fail "Ingress 'portal-ingress' not found in $NS"

RULE_HOST=$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].host}')
[ "$RULE_HOST" = "portal.ckx.local" ] || fail "Ingress rule host must be portal.ckx.local, got: $RULE_HOST"

BACKEND_SVC=$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}')
[ "$BACKEND_SVC" = "portal-svc" ] || fail "Ingress backend service must be portal-svc, got: $BACKEND_SVC"

BACKEND_PORT=$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')
[ "$BACKEND_PORT" = "80" ] || fail "Ingress backend port must be 80, got: $BACKEND_PORT"

echo "PASS: ingress routes portal.ckx.local to portal-svc:80"
exit 0
