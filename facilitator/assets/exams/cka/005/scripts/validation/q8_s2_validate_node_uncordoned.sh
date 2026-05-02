#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
[ -f /tmp/exam/q8/target-node.txt ] || fail "/tmp/exam/q8/target-node.txt not found"
NODE=$(cat /tmp/exam/q8/target-node.txt)
[ -n "$NODE" ] || fail "target-node.txt is empty"
UNSCHEDULABLE=$(kubectl get node "$NODE" \
  -o jsonpath='{.spec.unschedulable}' 2>/dev/null || echo "")
[ "$UNSCHEDULABLE" = "true" ] && fail "Node '$NODE' is still cordoned (unschedulable=true)"
STATUS=$(kubectl get node "$NODE" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
[ "$STATUS" = "True" ] || fail "Node '$NODE' not Ready (status='$STATUS')"
pass "Node '$NODE' is Ready and schedulable"
