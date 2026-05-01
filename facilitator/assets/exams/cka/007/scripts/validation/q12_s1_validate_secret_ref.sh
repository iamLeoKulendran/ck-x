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
NS=cka-q12
SEC=$(kubectl get deploy payment-worker -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_PASSWORD")].valueFrom.secretKeyRef.name}' 2>/dev/null)
KEY=$(kubectl get deploy payment-worker -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_PASSWORD")].valueFrom.secretKeyRef.key}' 2>/dev/null)
[ "$SEC" = "db-credentials" ] || fail "Secret name is $SEC"
[ "$KEY" = "password" ] || fail "Secret key is $KEY"
pass "Secret env reference is correct"
