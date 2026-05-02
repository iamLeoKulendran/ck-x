#!/bin/bash
set -euo pipefail
NS="rev1-q08"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

[ -f /tmp/exam/q8/target-node.txt ] || fail "/tmp/exam/q8/target-node.txt not found"
NODE=$(cat /tmp/exam/q8/target-node.txt)
[ -n "$NODE" ] || fail "target-node.txt is empty"

# Anchor on PDB fix — the node starts uncordoned so checking node state alone is a false positive.
# Without lowering minAvailable first, drain cannot succeed and uncordon has no meaning.
MIN=$(kubectl -n "$NS" get pdb api-pdb \
  -o jsonpath='{.spec.minAvailable}' 2>/dev/null || echo "")
[ "$MIN" = "1" ] \
  || fail "PDB api-pdb minAvailable='$MIN' — must be patched to 1 before drain is possible"

UNSCHEDULABLE=$(kubectl get node "$NODE" \
  -o jsonpath='{.spec.unschedulable}' 2>/dev/null || echo "")
[ "$UNSCHEDULABLE" = "true" ] && fail "Node '$NODE' is still cordoned (unschedulable=true)"

STATUS=$(kubectl get node "$NODE" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
[ "$STATUS" = "True" ] || fail "Node '$NODE' not Ready (status='$STATUS')"

pass "PDB patched and node '$NODE' is Ready and schedulable"
