#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q08
SVC=q8-web-svc
SEL=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.selector.app}')
[ "$SEL" = "q8-web" ] || fail "Expected selector app=q8-web, got $SEL"
PORT=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].port}')
TARGET=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].targetPort}')
[ "$PORT" = "80" ] || fail "Service port must be 80"
[ "$TARGET" = "80" ] || fail "Service targetPort must be 80"
pass "Service selector and ports are correct"
