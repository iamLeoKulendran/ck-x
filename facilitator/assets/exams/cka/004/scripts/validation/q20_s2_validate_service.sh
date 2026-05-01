#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q20
SVC=q20-api-svc
kubectl get svc "$SVC" -n "$NS" >/dev/null 2>&1 || fail "Service $SVC not found"
TYPE=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.type}')
SEL=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.selector.app}')
PORT=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].port}')
TARGET=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].targetPort}')
[ "$TYPE" = "NodePort" ] || fail "Service type must be NodePort"
[ "$SEL" = "q20-api" ] || fail "Service selector app must be q20-api"
[ "$PORT" = "8080" ] || fail "Service port must be 8080"
[ "$TARGET" = "80" ] || fail "Service targetPort must be 80"
pass "Service is correct"
