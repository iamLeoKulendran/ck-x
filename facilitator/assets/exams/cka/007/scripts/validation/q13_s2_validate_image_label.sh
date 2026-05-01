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
NS=cka-q13
IMG=$(kubectl get pod pinned-cache -n "$NS" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
LBL=$(kubectl get pod pinned-cache -n "$NS" -o jsonpath='{.metadata.labels.app}' 2>/dev/null)
[ "$IMG" = "nginx:1.27" ] || fail "image is $IMG"
[ "$LBL" = "pinned-cache" ] || fail "label app is $LBL"
pass "pod image and label are correct"
