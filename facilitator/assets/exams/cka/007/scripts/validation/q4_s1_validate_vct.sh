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
NS=cka-q04
NAME=$(kubectl get sts metrics-store -n "$NS" -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' 2>/dev/null)
STORAGE=$(kubectl get sts metrics-store -n "$NS" -o jsonpath='{.spec.volumeClaimTemplates[0].spec.resources.requests.storage}' 2>/dev/null)
ACCESS=$(kubectl get sts metrics-store -n "$NS" -o jsonpath='{.spec.volumeClaimTemplates[0].spec.accessModes[0]}' 2>/dev/null)
[ "$NAME" = "data" ] || fail "volumeClaimTemplates name is $NAME, expected data"
[ "$ACCESS" = "ReadWriteOnce" ] || fail "access mode is $ACCESS, expected ReadWriteOnce"
[ "$STORAGE" = "128Mi" ] || fail "storage request is $STORAGE, expected 128Mi"
pass "volumeClaimTemplates is correct"
