#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=default
POD=q2-control-plane-pod
NODE=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.nodeName}')
[ -n "$NODE" ] || fail "Pod is not scheduled"
kubectl get node "$NODE" -o jsonpath='{.metadata.labels.node-role\.kubernetes\.io/control-plane}{.metadata.labels.node-role\.kubernetes\.io/master}' | grep -q . || fail "Pod is not on a control-plane/master node"
kubectl get pod "$POD" -n "$NS" -o yaml | grep -Eq 'node-role.kubernetes.io/(control-plane|master)' || fail "Missing control-plane/master selector or toleration"
kubectl get pod "$POD" -n "$NS" -o yaml | grep -q 'NoSchedule' || fail "Missing NoSchedule toleration"
pass "Pod scheduling constraints are correct"
