#!/bin/bash
set +e

fail() {
  echo "❌ $1"
  exit 1
}

pass() {
  echo "✅ $1"
  exit 0
}
NS=cka-q10
PATH_VAL=$(kubectl get deploy catalog-web -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
PORT_VAL=$(kubectl get deploy catalog-web -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null)
[ "$PATH_VAL" = "/" ] || fail "readiness path is $PATH_VAL"
[ "$PORT_VAL" = "80" ] || fail "readiness port is $PORT_VAL"
pass "readiness probe fixed"
