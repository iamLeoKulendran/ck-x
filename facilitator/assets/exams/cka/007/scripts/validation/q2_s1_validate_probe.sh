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
NS=cka-q02
PATH_VAL=$(kubectl get deploy orders-web -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
PORT_VAL=$(kubectl get deploy orders-web -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null)
[ "$PATH_VAL" = "/" ] || fail "readiness path is $PATH_VAL, expected /"
[ "$PORT_VAL" = "80" ] || fail "readiness port is $PORT_VAL, expected 80"
pass "readiness probe is correct"
