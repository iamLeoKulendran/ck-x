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
MOUNT_NAME=$(kubectl get sts metrics-store -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.mountPath=="/usr/share/nginx/html")].name}' 2>/dev/null)
[ "$MOUNT_NAME" = "data" ] || fail "expected data mounted at /usr/share/nginx/html, got $MOUNT_NAME"
pass "persistent claim is mounted correctly"
