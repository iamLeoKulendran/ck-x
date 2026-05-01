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
NS=cka-q07
IMG=$(kubectl get job checksum-job -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
CMD=$(kubectl get job checksum-job -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].command[*]}' 2>/dev/null)
ARGS=$(kubectl get job checksum-job -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].args[*]}' 2>/dev/null)
[ "$IMG" = "busybox:1.36" ] || fail "image is $IMG"
echo "$CMD $ARGS" | grep -q 'checksum-ok' || fail "command does not print checksum-ok"
pass "Job image and command are correct"
