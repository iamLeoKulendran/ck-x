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
NS=cka-q11
CM=$(kubectl get deploy config-consumer -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_MODE")].valueFrom.configMapKeyRef.name}' 2>/dev/null)
KEY=$(kubectl get deploy config-consumer -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_MODE")].valueFrom.configMapKeyRef.key}' 2>/dev/null)
[ "$CM" = "app-settings" ] || fail "ConfigMap name is $CM"
[ "$KEY" = "APP_MODE" ] || fail "ConfigMap key is $KEY, expected APP_MODE"
pass "ConfigMap env reference is correct"
