#!/bin/bash
set -euo pipefail
NS="rev1-q17"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get service dual-svc >/dev/null 2>&1 || fail "Service dual-svc not found"
COUNT=$(kubectl -n "$NS" get endpoints dual-svc \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | \
  python3 -c "import json,sys; d=sys.stdin.read().strip(); print(len(json.loads(d)) if d and d!='null' else 0)" \
  2>/dev/null || echo "0")
[ "${COUNT:-0}" -ge 3 ] || fail "Service has ${COUNT:-0} endpoint addresses, expected >= 3"
pass "Service dual-svc has $COUNT endpoint addresses"
