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
NS=cka-q14
kubectl rollout status deploy/reporting-api -n "$NS" --timeout=15s >/dev/null 2>&1 || fail "reporting-api not available"
for NODE in $(kubectl get pods -n "$NS" -l app=reporting-api -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}'); do
  VAL=$(kubectl get node "$NODE" -o jsonpath='{.metadata.labels.q14\.disk}' 2>/dev/null)
  [ "$VAL" = "ssd" ] || fail "pod scheduled on node $NODE without q14.disk=ssd"
done
pass "all pods run on SSD-labeled nodes"
