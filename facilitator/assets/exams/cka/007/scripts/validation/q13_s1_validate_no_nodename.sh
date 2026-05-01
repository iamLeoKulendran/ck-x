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
NN=$(kubectl get pod pinned-cache -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
[ -n "$NN" ] || fail "pod is not scheduled on any node yet"
[ "$NN" != "ghost-node" ] || fail "pod is still pinned to ghost-node"
kubectl get node "$NN" >/dev/null 2>&1 || fail "scheduled node $NN does not exist"
pass "pod is scheduled on a real node"
